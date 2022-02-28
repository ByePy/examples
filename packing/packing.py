"""
ByePy - TPC-H Packing Example
Copyright (C) 2022  Tim Fischer

packing.py

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

from __future__ import annotations
from dataclasses import dataclass
from math import sqrt
from pathlib import Path
import os

from dotenv import load_dotenv
from byepy import connect, SQL, DO, to_compile


load_dotenv()
connect(os.getenv("TPC-H_AUTH_STR"))


@to_compile
def pack(orderkey: int, capacity: int) -> list[list[int]]:
    # # of lineitems in order
    n: int = SQL(
        """
        SELECT COUNT(*) :: int4
        FROM   lineitem AS l
        WHERE  l.l_orderkey = $1
        """,
        [orderkey],
    )

    if (
        # order key not found?
        n == 0
        # container capacity sufficient to hold largest part?
        or capacity
        < SQL(
            """
            SELECT MAX(p.p_size)
            FROM   lineitem AS l, part AS p
            WHERE  l.l_orderkey = $1
            AND    l.l_partkey  = p.p_partkey
            """,
            [orderkey],
        )
    ):
        return []

    # initialize empty pack of packs
    packs: list[list[int]] = []
    # create full set of linenumbers {1,2,...,n}
    items: int = (1 << n) - 1

    # as long as there are still lineitems to pack...
    while items != 0:
        max_size = 0
        max_subset = 0  # ∅

        subset = items & -items

        while True:
            # find size of current lineitem subset o
            size: int = SQL(
                """
                SELECT SUM(p.p_size) :: int4
                FROM   lineitem AS l, part AS p
                WHERE  l.l_orderkey = $1
                AND    $2 & (1 << l.l_linenumber - 1) <> 0
                AND    l.l_partkey = p.p_partkey
                """,
                [orderkey, subset],
            )

            if size <= capacity and size > max_size:
                max_size = size
                max_subset = subset

            # exit if iterated through all lineitem subsets ...
            if subset == items:
                break
            else:
                # ... else, consider next lineitem subset
                subset = items & (subset - items)

        # convert bit set max_subset into set of linenumbers
        pack: list[int] = []
        for linenumber in range(n):
            pack.append(
                linenumber + 1
                if max_subset & (1 << linenumber) != 0
                else 0
            )

        # add pack to current packing
        packs.append(pack)

        # we've selected lineitems in set max_subset,
        # update items to remove these lineitems
        items &= ~max_subset

    return packs


with open(Path(__file__).parent / "packing.sql", "r") as f:
    COMP_QUERY = f.read()


def pack_comp(orderkey: int, capacity: int) -> list[list[int]]:
    return SQL(COMP_QUERY, [orderkey, capacity])


if __name__ == "__main__":
    from time import time

    CAPACITY = 10
    # pack all finished orders
    orders: list[int] = SQL(
        """
        SELECT ARRAY_AGG(o)
        FROM   (SELECT o.o_orderkey
                FROM   orders AS o
                WHERE  o.o_orderstatus = 'F'
                LIMIT  10000) AS _(o)
        """
    )
    funcs = {
        "python": pack,
        "byepy": pack_comp,
    }

    for name, func in funcs.items():
        start = time()
        for order in orders:
            print(func(order, CAPACITY))
        end = time()
        print(name, (end - start) * 1000)
