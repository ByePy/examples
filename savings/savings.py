"""
ByePy - TPC-H Savings Example
Copyright (C) 2022  Tim Fischer

savings.py

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""

from dataclasses import dataclass
from datetime import date
from pathlib import Path
import os

from dotenv import load_dotenv
from byepy import connect, DO, DEFINE, coalesce, register_composite, to_compile, SQL

load_dotenv()
connect(os.getenv("TPC-H_AUTH_STR"))

DEFINE(
    """
    SELECT;  -- Just to trigger the syntax highlighting in sublime text!

    -- PL/SQL function to change the suppliers for a given TPC-H order
    -- such that the supply cost for all parts are minimal.  Return savings
    -- in % as well as an array listing the required supply chain changes
    -- (‹part›, ‹old supplier›, ‹new supplier›).

    -- representation of a supplier change
    DROP TYPE IF EXISTS supplierchange CASCADE;
    CREATE TYPE supplierchange AS (
      part int,  -- part for which supplier changed
      old  int,  -- old supplier
      new  int   -- new supplier
    );

    -- representation of supply chain changes
    DROP TYPE IF EXISTS savings CASCADE;
    CREATE TYPE savings AS (
      savings          numeric(4,1),     -- saved supply cost (in %)
      supplierchanges supplierchange[] -- supplier changes required to achieve savings
    );
    """
)


@register_composite
@dataclass
class SupplierChange:
    part: int
    old: int
    new: int


@register_composite
@dataclass
class Savings:
    savings: float
    supplierchanges: list[SupplierChange]


@register_composite
@dataclass
class PartSupp:
    ps_partkey: int
    ps_suppkey: int
    ps_availqty: int
    ps_supplycost: float
    ps_comment: str


@register_composite
@dataclass
class Orders:
    o_orderkey: int
    o_custkey: int
    o_orderstatus: str
    o_totalprice: float
    o_orderdate: date
    o_orderpriority: str
    o_clerk: str
    o_shippriority: int
    o_comment: str


@register_composite
@dataclass
class LineItem:
    l_orderkey: int
    l_partkey: int
    l_suppkey: int
    l_linenumber: int
    l_quantity: float
    l_extendedprice: float
    l_discount: float
    l_tax: float
    l_returnflag: str
    l_linestatus: str
    l_shipdate: date
    l_commitdate: date
    l_receiptdate: date
    l_shipinstruct: str
    l_shipmode: str
    l_comment: str


@to_compile
def savings(orderkey: int) -> Savings | None:
    order: Orders = SQL(
        """
        SELECT o :: orders
        FROM   orders as o
        WHERE  o.o_orderkey = $1
        """,
        [orderkey],
    )

    if order is None:
        return None

    items: int = SQL(
        """
        SELECT COUNT(*) :: int4
        FROM   lineitem as l
        WHERE  l.l_orderkey = $1
        """,
        [orderkey],
    )
    total_supplycost = 0.0
    new_supplycost = 0.0
    new_suppliers: list[SupplierChange] = []

    for item in range(1, items + 1):
        lineitem: LineItem = SQL(
            """
            SELECT l :: lineitem
            FROM   lineitem AS l
            WHERE  l.l_orderkey = $1
            AND    l.l_linenumber = $2
            """,
            [orderkey, item],
        )
        partsupp: PartSupp = SQL(
            """
            SELECT ps :: partsupp
            FROM   partsupp AS ps
            WHERE  ($1 :: lineitem).l_partkey = ps.ps_partkey
            AND    ($1 :: lineitem).l_suppkey = ps.ps_suppkey
            """,
            [lineitem],
        )
        min_supplycost: float = SQL(
            """
            SELECT min(ps.ps_supplycost) :: float
            FROM   partsupp AS ps
            WHERE  ps.ps_partkey  =  ($1 :: lineitem).l_partkey
            AND    ps.ps_availqty >= ($1 :: lineitem).l_quantity
            """,
            [lineitem],
        )
        new_supplier: int = SQL(
            """
            SELECT min(ps.ps_suppkey)
            FROM   partsupp AS ps
            WHERE  ps.ps_supplycost = $1
            AND    ps.ps_partkey    = ($2 :: lineitem).l_partkey
            """,
            [min_supplycost, lineitem],
        )

        if new_supplier != partsupp.ps_suppkey:
            new_suppliers.append(
                SupplierChange(lineitem.l_partkey, partsupp.ps_suppkey, new_supplier)
            )

        total_supplycost += partsupp.ps_supplycost * lineitem.l_quantity
        new_supplycost += min_supplycost * lineitem.l_quantity

    return Savings((1 - new_supplycost / total_supplycost) * 100.0, new_suppliers)


with open(Path(__file__).parent / "savings.sql", "r") as f:
    DO(f.read())


def savings_comp(orderkey: int) -> Savings | None:
    return SQL("SELECT savings_start($1);", [orderkey])
def savings_plpython(orderkey: int) -> Savings | None:
    return SQL("SELECT savings_plpython($1);", [orderkey])
def savings_plsql(orderkey: int) -> Savings | None:
    return SQL("SELECT savings_plsql($1);", [orderkey])


if __name__ == "__main__":
    from time import time

    orders: list[int] = SQL(
        """
        SELECT array_agg(o)
        FROM (SELECT o.o_orderkey
              FROM orders AS o
              WHERE o.o_orderstatus = 'O'
              LIMIT 500) AS _(o)
        """
    )
    funcs = {
        "python": savings,
        "byepy": savings_comp,
        "plpython": savings_plpython,
        "plsql": savings_plsql,
    }

    for name, func in funcs.items():
        start = time()
        for order in orders:
            func(order)
        end = time()
        print(name, (end - start) * 1000)
