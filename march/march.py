"""
ByePy - Marching Squares Example
Copyright (C) 2022  Tim Fischer

march.py

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
from byepy import connect, SQL, DO, DEFINE, register_composite, to_compile


load_dotenv()
connect(os.getenv("AUTH_STR"))


DEFINE(
    """SELECT; -- Just to trigger the syntax highlighting in sublime text!

    -- A vector/point in 2D Cartesian space
    DROP TYPE IF EXISTS Vec2i CASCADE;
    CREATE TYPE Vec2i AS
        ( x int
        , y int
        );

    -- Representation of 2D height map
    DROP TABLE IF EXISTS map CASCADE;
    CREATE TABLE map
        ( xy Vec2i PRIMARY KEY
        , alt int
        );

    -- Tabular encoding of the essence of the marching square algorithm:
    -- direct the march based on a 2×2 vicinity of pixels
    DROP TABLE IF EXISTS directions CASCADE;
    CREATE TABLE directions
        ( ll bool    -- pixel set in the lower left?
        , lr bool    --                  lower right
        , ul bool    --                  upper left
        , ur bool    --                  upper right
        , dir Vec2i  -- direction of march
        , track bool -- are we tracking the shape yet?
        , PRIMARY KEY (ll, lr, ul, ur)
        );

    -- Generate a thresholded black/white 2D map of pixels
    DROP TABLE IF EXISTS pixels CASCADE;
    CREATE TABLE pixels
        ( xy  Vec2i PRIMARY KEY
        , alt bool
        );

    -- Generate a 2D map of squares that each aggregate 2×2 adjacent pixel
    DROP TABLE IF EXISTS squares CASCADE;
    CREATE TABLE squares
        ( xy Vec2i PRIMARY KEY
        , ll bool
        , lr bool
        , ul bool
        , ur bool
        );
    """
)

N = 100
STRIPE = 8

DO(
    """
    SELECT setseed(0.42);

    INSERT INTO map(xy, alt)
      SELECT (x + $1, y) :: Vec2i AS xy,
             -- ellipse with center (:X/2, :Y/2) and radii :X/2-1 and :Y/2-1
             CASE WHEN ((x - $2 / 2.0)^2 / ($2 / 2.0 - 1)^2) +
                       ((y - $3 / 2.0)^2 / ($3 / 2.0 - 1)^2) <= 1
                  THEN 1000
                  ELSE 0
             END AS alt
      FROM   generate_series(-$1, $2) AS x,
             generate_series(  0, $3) AS y;

    INSERT INTO directions(ll, lr, ul, ur, dir, track) VALUES
      (false,false,false,false, ( 1, 0) :: Vec2i, false), -- | | ︎: →
      (false,false,false,true , ( 1, 0) :: Vec2i, true ), -- |▝| : →
      (false,false,true ,false, ( 0, 1) :: Vec2i, true ), -- |▘| : ↑
      (false,false,true ,true , ( 1, 0) :: Vec2i, true ), -- |▀| : →
      (false,true ,false,false, ( 0,-1) :: Vec2i, true ), -- |▗| : ↓
      (false,true ,false,true , ( 0,-1) :: Vec2i, true ), -- |▐| : ↓
      (false,true ,true ,false, ( 0, 1) :: Vec2i, true ), -- |▚| : ↑
      (false,true ,true ,true , ( 0,-1) :: Vec2i, true ), -- |▜| : ↓
      (true ,false,false,false, (-1, 0) :: Vec2i, true ), -- |▖| : ←
      (true ,false,false,true , (-1, 0) :: Vec2i, true ), -- |▞| : ←
      (true ,false,true ,false, ( 0, 1) :: Vec2i, true ), -- |▌| : ↑
      (true ,false,true ,true , ( 1, 0) :: Vec2i, true ), -- |▛| : →
      (true ,true ,false,false, (-1, 0) :: Vec2i, true ), -- |▄| : ←
      (true ,true ,false,true , (-1, 0) :: Vec2i, true ), -- |▟| : ←
      (true ,true ,true ,false, ( 0, 1) :: Vec2i, true ), -- |▛| : →
      (true ,true ,true ,true , NULL            , true ); -- |█| : x

    INSERT INTO pixels(xy, alt)
      -- Threshold height map based on given iso value (here: > 700)
      SELECT m.xy, m.alt > 700 AS alt
      FROM   map AS m;

    INSERT INTO squares(xy, ll, lr, ul, ur)
      -- Establish 2×2 squares on the pixel-fied map,
      -- (x,y) designates lower-left corner: ul  ur
      --                                       ⬜︎
      --                                     ll  lr
      SELECT p0.xy AS xy,
             p0.alt AS ll, p1.alt AS lr, p2.alt AS ul, p3.alt AS ur
      FROM   pixels p0, pixels p1, pixels p2, pixels p3
      WHERE  p1.xy = ((p0.xy).x + 1, (p0.xy).y + 0) :: Vec2i
      AND    p2.xy = ((p0.xy).x + 0, (p0.xy).y + 1) :: Vec2i
      AND    p3.xy = ((p0.xy).x + 1, (p0.xy).y + 1) :: Vec2i;

    analyze squares; analyze directions; analyze map;
    """,
    [
        STRIPE,  # stripe
        N,  # X
        N,  # Y
    ],
)


@register_composite
@dataclass
class Vec2i:
    x: int
    y: int

    def __hash__(self): # only needed for output validation!
        return hash((self.x,self.y))


@register_composite
@dataclass
class Directions:
    ll: bool
    lr: bool
    ul: bool
    ur: bool
    dir: Vec2i
    track: bool


@register_composite
@dataclass
class Squares:
    xy: Vec2i
    ll: bool
    lr: bool
    ul: bool
    ur: bool


@to_compile
def march(start: Vec2i) -> list[Vec2i]:
    goal: Vec2i | None = None
    track: bool = False
    march: list[Vec2i] = []
    current: Vec2i = start

    while True:
        if track and current == goal:
            break

        square: Squares = SQL(
            """
            SELECT s :: squares
              FROM squares AS s
             WHERE s.xy = $1
            """,
            [current],
        )
        dir: Directions = SQL(
            """
            SELECT d :: directions
              FROM directions AS d
             WHERE ($1 :: squares).ll = "d"."ll"
               AND ($1 :: squares).lr = "d"."lr"
               AND ($1 :: squares).ul = "d"."ul"
               AND ($1 :: squares).ur = "d"."ur"
            """,
            [square],
        )

        if not track and dir.track:
            track = True
            goal = current
        if track:
            march.append(current)

        current = Vec2i(current.x + dir.dir.x, current.y + dir.dir.y)

    return march


with open(Path(__file__).parent / "march.sql", "r") as f:
    DO(f.read())


def march_comp(start: Vec2i) -> list[Vec2i]:
    return SQL("SELECT march_start($1);", [start])
def march_plpython(start: Vec2i) -> list[Vec2i]:
    return SQL("SELECT march_plpython($1);", [start])
def march_plsql(start: Vec2i) -> list[Vec2i]:
    return SQL("SELECT march_plsql($1);", [start])


if __name__ == "__main__":
    from math import floor
    from random import random
    from time import time

    funcs = {
        "python": march,
        "byepy": march_comp,
        "plpython": march_plpython,
        "plsql": march_plsql,
    }
    inputs = [
        Vec2i( floor(    random() * STRIPE)
             , floor(1 + random() * (N - 1))
             )
        for i in range(1, N+1)
    ]

    for name, func in funcs.items():
        start = time()
        for input in inputs:
            func(input)
        end = time()
        print(name, (end - start) * 1000)
