"""
ByePy - Barnes-Hut Example
Copyright (C) 2022  Tim Fischer

barnes_hut.py

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
import os
from pathlib import Path

from dotenv import load_dotenv
from byepy import connect, SQL, DO, DEFINE, register_composite, to_compile

load_dotenv()
connect(os.getenv("AUTH_STR"))

DEFINE(
    """SELECT; -- Just to trigger the syntax highlighting in sublime text!

    DROP TABLE IF EXISTS bodies CASCADE;
    CREATE TABLE bodies
      ( x float
      , y float
      , mass float
      );

    DROP TABLE IF EXISTS walls CASCADE;
    CREATE TABLE walls
      ( wall line
      );

    DROP TABLE IF EXISTS barneshut CASCADE;
    CREATE TABLE barneshut
      ( node int
      , parent int
      , mass float
      , size float
      , x float
      , y float
      );

    DROP TYPE IF EXISTS Vec2f CASCADE;
    CREATE TYPE Vec2f AS
      ( x float
      , y float
      );
    """
)

DO(
    """
    SELECT setseed(0.42);

    -- Populate area with N random bodies
    DROP TABLE IF EXISTS bodies CASCADE;
    CREATE TABLE bodies AS
      SELECT $1 * random() AS x
           , $1 * random() AS y
           , GREATEST(1.0, 10 * random()) AS mass
      FROM   generate_series(1, $2);

    SELECT setseed(0.42);

    -- Populate area with W random walls
    DROP TABLE IF EXISTS walls CASCADE;
    CREATE TABLE walls AS
      SELECT line(point($1 * random(),
                        $1 * random()),
                  point($1 * random(),
                        $1 * random())) AS wall
      FROM   generate_series(1, $2 / 100);

    -- Table barneshut(node, size, parent, mass, x, y) stores
    -- the quad-tree.  Leaf nodes represent the bodies themselves.
    --
    -- node (int)     id of internal quad-tree node (NULL for bodies ≡ leaves)
    -- size (float)   width of the enclosing bounding box of this node (leaf: encloses body only)
    -- parent (int)   parent node
    -- mass (float)   aggregate mass of subtree below node (leaf: mass of body)
    -- x (float)      x coordinate of the weigthed center of mass of subtree below node (leaf: body position)
    -- y (float)      y coordinate of the weigthed center of mass of subtree below node (leaf: body position)

    DROP TABLE IF EXISTS barneshut;
    CREATE TABLE barneshut AS
      -- Build complete quad-tree for :area
      WITH RECURSIVE
        -- ➊ Construct inner nodes of quad-tree (top-down, starting from the root)
        skeleton(node, bbox, parent) AS (
          SELECT 0 AS node, box(point(0,0),point($1,$1)) AS bbox, NULL :: int AS parent
            UNION ALL
          SELECT n.*
          FROM   skeleton AS s,
                 LATERAL (VALUES (center(s.bbox), width(s.bbox) / 2)) AS _(c,w),
                 LATERAL (VALUES (s.node * 4 + 1, box(c, c + point( w, w)), s.node),
                                 (s.node * 4 + 2, box(c, c + point(-w, w)), s.node),
                                 (s.node * 4 + 3, box(c, c + point( w,-w)), s.node),
                                 (s.node * 4 + 4, box(c, c + point(-w,-w)), s.node)) AS n(node,bbox,parent)
          -- create quad-tree node only if it indeed hosts more than one body
          WHERE (SELECT COUNT(*) FROM bodies AS b WHERE point(b.x,b.y) <@ n.bbox) >= 2
        ),
        -- ➋ Add bodies as quad-tree leaves (hanging off the inner nodes covering minimal area)
        quadtree(node, bbox, parent, mass) AS (
          SELECT s.node, s.bbox, s.parent, NULL :: float AS mass
          FROM   skeleton AS s
            UNION ALL                                           -- ⚠️ not recursive
          SELECT NULL AS node, box(point(b.x,b.y), point(b.x,b.y)) AS bbox,
                 (SELECT s.node
                  FROM   skeleton AS s
                  WHERE  point(b.x,b.y) <@ s.bbox
                  -- if two bounding boxes overlap, place body b in node s with smaller ID
                  ORDER BY area(s.bbox), s.node
                  LIMIT 1) AS parent,
                 b.mass AS mass
          FROM   bodies AS b
        ),
        -- ➌ Annotate all quad-tree nodes with their total mass and centre of mass (bottom-up)
        barneshut(node, bbox, parent, mass, center) AS (
          SELECT q.node, q.bbox, q.parent,
                 q.mass,
                 center(q.bbox) AS center
          FROM   quadtree AS q
          WHERE  q.node IS NULL      -- ≡ is q a leaf?
            UNION ALL
          SELECT DISTINCT ON (q.node) q.node, q.bbox, q.parent,
                 SUM(b.mass) OVER (PARTITION BY q.node) AS mass,  -- ─────────────────────────────────── ≡ mass
                 SUM(b.mass * b.center) OVER (PARTITION BY q.node) / SUM(b.mass) OVER (PARTITION BY q.node) AS center -- ⧆
          FROM   quadtree AS q, barneshut AS b
          WHERE  q.node = b.parent
        )
        SELECT b.node                                    AS node
             , b.parent                                  AS parent
             , SUM(b.mass)                               AS mass
             , width(b.bbox)                             AS size
             , (SUM(b.mass * b.center) / SUM(b.mass))[0] AS x
             , (SUM(b.mass * b.center) / SUM(b.mass))[1] AS y
        FROM   barneshut AS b
        GROUP BY b.node, b.bbox, b.parent, center(b.bbox);
        --                                      🠵
        --              additional grouping criterion to differentiate
        --              between leaf bounding boxes below the same parent
        --              (PostgreSQL considers any two boxes of width 0
        --               to be equal, no matter what their center point is)
    """,
    [
        1000,  # size
        1000,  # N
    ],
)


@register_composite
@dataclass
class Bodies:
    x: float
    y: float
    mass: float


@register_composite
@dataclass
class Barneshut:
    node: int
    parent: int
    mass: float
    size: float
    x: float
    y: float


@register_composite
@dataclass
class Vec2f:
    x: float
    y: float


@to_compile
def force(body: Bodies, theta: float) -> Vec2f:
    G = 6.67e-11
    node: Barneshut = SQL(
        """
        SELECT b
        FROM   barneshut AS b
        WHERE  node = 0
        """
    )
    Q: list[Barneshut] = [node]
    fx = 0.0
    fy = 0.0

    while len(Q) > 0:
        node = Q.pop()
        dist = max(
            sqrt((node.x - body.x) ** 2 + (node.y - body.y) ** 2),
            1e-10,
        )

        if node.node is None or node.size / dist < theta:
            if SQL(
                """
              SELECT NOT EXISTS (
                  SELECT 1
                  FROM walls AS w
                  WHERE (pos    <= pos    ## w.wall)
                     <> (center <= center ## w.wall))
              FROM (SELECT point( ($1 :: bodies   ).x
                                , ($1 :: bodies   ).y
                                ),
                           point( ($2 :: barneshut).x
                                , ($2 :: barneshut).y)
                                ) AS _(pos, center)
              """,
                [body, node],
            ):
                fac = G * body.mass * node.mass / (dist ** 2)
                fx += (node.x - body.x) * fac
                fy += (node.y - body.y) * fac
        else:
            Q.extend(
                SQL(
                    """
                    SELECT array_agg(b) :: barneshut[]
                    FROM   barneshut AS b
                    WHERE  b.parent = $1
                    """,
                    [node.node],
                )
            )

    return Vec2f(fx, fy)


with open(Path(__file__).parent / "barnes_hut.sql", "r") as f:
    DO(f.read())


def force_comp(body: Bodies, theta: float) -> Vec2f:
    return SQL("SELECT force_start($1, $2);", [body, theta])
def force_plpython(body: Bodies, theta: float) -> Vec2f:
    return SQL("SELECT force_plpython($1, $2);", [body, theta])
def force_plsql(body: Bodies, theta: float) -> Vec2f:
    return SQL("SELECT force_plsql($1, $2);", [body, theta])


if __name__ == "__main__":
    from math import floor
    from random import random
    from time import time

    funcs = {
        "python": force,
        "byepy": force_comp,
        "plpython": force_plpython,
        "plsql": force_plsql,
    }
    bodies = [Bodies(1000 * random(), 1000 * random(), 1.0) for _ in range(1000)]

    for name, func in funcs.items():
        start = time()
        for body in bodies:
            func(body, 0.5)
        end = time()
        print(name, (end - start) * 1000)
