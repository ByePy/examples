"""
ByePy - TPC-H Margins Example
Copyright (C) 2022  Tim Fischer

margin.py

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

    -- index that can help queries ➊ and ➌
    DROP INDEX IF EXISTS orders_o_orderdate_o_orderkey;
    CREATE INDEX orders_o_orderdate_o_orderkey ON orders USING btree(o_orderdate, o_orderkey);
    ANALYZE orders;

    -- index that can help query ➋
    DROP INDEX IF EXISTS lineitem_l_partkey_l_orderkey;
    CREATE INDEX lineitem_l_partkey_l_orderkey ON lineitem USING btree(l_partkey, l_orderkey);
    ANALYZE lineitem;

    -- trade: buying/selling a part in these orders yields indicated margin
    DROP TYPE IF EXISTS trade CASCADE;
    CREATE TYPE trade AS (
      buy    int,   -- buy part of this order and...
      sell   int,   -- sell part of this order, this...
      margin float  -- ... will be your margin
    );

    -- dated order: order happened on indicated date
    -- (NB: in TPC-H, o_orderkey does NOT ascend with o_orderdate)
    DROP TYPE IF EXISTS datedorder CASCADE;
    CREATE TYPE datedorder AS (
      orderkey  int,  -- this order was placed...
      orderdate date  -- ... on this date
    );

    DROP TYPE IF EXISTS minpart CASCADE;
    CREATE TYPE minpart AS (
      partkey int,
      name text
    );

    """
)


@register_composite
@dataclass
class DatedOrder:
    orderkey: int
    orderdate: date


@register_composite
@dataclass
class Trade:
    buy: int
    sell: int
    margin: float


@register_composite
@dataclass
class MinPart:
    partkey: int
    name: str



@to_compile
def margin(partkey: int) -> Trade:
    cheapest: float = float('+inf')
    margin: float = float('-inf')

    # ➊ first order for the given part
    this_order: DatedOrder | None = SQL(
        """
        SELECT (o.o_orderkey, o.o_orderdate) :: datedorder
        FROM   lineitem AS l, orders AS o
        WHERE  l.l_orderkey = o.o_orderkey
        AND    l.l_partkey  = $1
        ORDER BY o.o_orderdate
        LIMIT 1
        """,
        [partkey]
    )

    # hunt for the best margin while there are more orders to consider
    while this_order is not None:
        # ➋ price of part in this order
        price: float = SQL(
            """
            SELECT MIN(l.l_extendedprice * (1 - l.l_discount) * (1 + l.l_tax)) :: float8
            FROM   lineitem AS l
            WHERE  l.l_partkey  = $1
            AND    l.l_orderkey = ($2 :: datedorder).orderkey
            """,
            [partkey, this_order]
        )

        # if this is the new cheapest price, remember it
        if price <= cheapest:
            cheapest       = price
            cheapest_order = this_order.orderkey

        # compute current obtainable margin
        profit = price - cheapest
        if profit >= margin:
            buy    = cheapest_order
            sell   = this_order.orderkey
            margin = profit

        # ➌ find next order (if any) that traded the part
        this_order = SQL(
            """
            SELECT (o.o_orderkey, o.o_orderdate) :: datedorder
            FROM   lineitem AS l, orders AS o
            WHERE  l.l_orderkey = o.o_orderkey
            AND    l.l_partkey  = ($1)
            AND    o.o_orderdate > ($2 :: datedorder).orderdate
            ORDER BY o.o_orderdate
            LIMIT 1
            """,
            [partkey, this_order]
        )

    t = Trade(buy, sell, margin)
    return t


with open(Path(__file__).parent / "margin.sql", "r") as f:
    DO(f.read())

def margin_comp(partkey: int) -> Trade:
    return SQL("SELECT margin_start($1);", [partkey])
def margin_plpython(partkey: int) -> Trade:
    return SQL("SELECT margin_plpython($1);", [partkey])
def margin_plsql(partkey: int) -> Trade:
    return SQL("SELECT margin_plsql($1);", [partkey])


if __name__ == "__main__":
    from time import time

    parts: list[MinPart] = SQL(
        """
        SELECT array_agg(p :: minpart)
        FROM (SELECT p.p_partkey, p.p_name
              FROM part AS p
              LIMIT 1000) AS p
        """
    )
    funcs = {
        "python": margin,
        "byepy": margin_comp,
        "plpython": margin_plpython,
        "plsql": margin_plsql,
    }

    for name, func in funcs.items():
        start = time()
        for part in parts:
            func(part.partkey)
        end = time()
        print(name, (end - start) * 1000)
