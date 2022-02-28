"""
ByePy - Markov Robot Example
Copyright (C) 2022  Tim Fischer

markov.py

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

import os
from random import random
from math import copysign
from pathlib import Path
from dataclasses import dataclass

from dotenv import load_dotenv
from byepy import connect, DO, DEFINE, SQL, to_compile


load_dotenv()
connect(os.getenv("AUTH_STR"))

POINT_RANGE_X        = -2.0
POINT_RANGE_Y        =  2.0
WIDTH                = 10
HEIGHT               = 10
INACCESSIBLE_SQUARES = 10

# Setup database schema
DEFINE(
    """SELECT;  -- Just to trigger the syntax highlighting in sublime text!

    DROP TABLE IF EXISTS actions CASCADE;
    DROP TABLE IF EXISTS policy  CASCADE;
    DROP TABLE IF EXISTS states  CASCADE;
    DROP TABLE IF EXISTS utility CASCADE;

    -- A state with a name and a reward
    CREATE TABLE states
        ( id   int4 PRIMARY KEY
        , name text
        , r    float8
        );

    -- Each action is identified by its name and state it
    -- can be done from. The key, however, is an int4
    -- column "id"
    CREATE TABLE actions
        ( id     int4 PRIMARY KEY
        , name   text
        , s_from int4 REFERENCES states(id)
        , s_to   int4 REFERENCES states(id)
        , p      float8 CHECK (actions.p BETWEEN 0.0 AND 1.0)
        );
    CREATE SEQUENCE action_ids
        AS int4
        NO CYCLE
        OWNED BY actions.id
        ;

    -- The policy describing the one action to do (by name)
    -- in a given state state_id
    CREATE TABLE policy
        ( state_id    int4 REFERENCES states(id)
        , action_name text
        );

    -- The utility holding the predicted reward v in a given
    -- state state_id
    CREATE TABLE utility
        ( state_id int4
        , v        float8
        );
    """
)

# Setup demo instance
DO(
    """
    INSERT INTO states
        (SELECT row_number() OVER ()
              , (  '('
                || gs_x.v
                || ','
                || gs_y.v
                || ')'
                )
              , floor( random()
                     * (abs($1) + abs($2))
                     + $1
                     )
           FROM generate_series(0, $3 - 1) AS gs_x(v)
              , generate_series(0, $4 - 1) AS gs_y(v)
        );

    DROP TABLE IF EXISTS walls CASCADE;
    CREATE TEMP TABLE walls AS
        (SELECT s.id
              , s.name
              , NULL AS r
           FROM states AS s
              , (SELECT floor(random() * $3 * $4) + 1
                   FROM generate_series(1, $5)
                ) AS inaccessible(id)
          WHERE s.id = inaccessible.id
        );

    DELETE FROM states
        USING (SELECT w.id
                 FROM walls AS w
              ) AS inaccessible(id)
        WHERE states.id = inaccessible.id
        ;

    -- Initialize the actions and their possible outcomes.
    -- Here: The robot can try to move either ↑, ↓, ← or →.
    -- There is a 80% chance this succeeds.
    -- Otherwise, it fails by steering either 90° to the left
    -- (10%) or 90° to the right (10%).
    -- If the robot reaches 's', it stops there accumulating
    -- that field's reward indefinitely
    INSERT INTO actions(id, name, s_from, s_to, p)
        (SELECT nextval('action_ids')
              , a.name
              , a.s_from
              , a.s_to
              , SUM(a.p) AS p
           FROM (SELECT d.v
                      , current_s.id
                      , CASE WHEN NOT EXISTS (SELECT NULL
                                                FROM states AS s
                                               WHERE s.name
                                                   = (  '('
                                                     || (x.v + d.dx)
                                                     || ','
                                                     || (y.v + d.dy)
                                                     || ')'
                                                     )
                                             )
                             THEN current_s.id
                             ELSE (SELECT s.id
                                     FROM states AS s
                                    WHERE s.name
                                        = (  '('
                                          || (x.v + d.dx)
                                          || ','
                                          || (y.v + d.dy)
                                          || ')'
                                          )
                                  )
                        END
                      , d.p
                   FROM generate_series(0, $3 - 1) AS x(v)
                      , generate_series(0, $4 - 1) AS y(v)
                      , (VALUES ('↑', 0.8,0,-1), ('↑', 0.1,-1,0), ('↑', 0.1,+1,0)
                              , ('↓', 0.8,0,+1), ('↓', 0.1,-1,0), ('↓', 0.1,+1,0)
                              , ('←', 0.8,-1,0), ('←', 0.1,0,-1), ('←', 0.1,0,+1)
                              , ('→', 0.8,+1,0), ('→', 0.1,0,-1), ('→', 0.1,0,+1)
                        ) AS d(v,p,dx,dy)
                      , LATERAL (SELECT s.id
                                   FROM states AS s
                                  WHERE s.name
                                      = (  '('
                                        || x.v
                                        || ','
                                        || y.v
                                        || ')'
                                        )
                                ) AS current_s(id)
                ) AS a(name, s_from, s_to, p)
          GROUP BY ( a.s_from
                   , a.name
                   , a.s_to
                   )
        );

    -- Initialize policy
    INSERT INTO policy
        (SELECT s.id
              , '↑'
           FROM states AS s
        );

    -- Initialize utility
    INSERT INTO utility
        (SELECT s.id
              , s.r + res.sum
           FROM states AS s
              , (SELECT a.s_from
                      , sum(a.p * s_to.r) AS sum
                   FROM states  AS s_from
                      , states  AS s_to
                      , actions AS a
                      , policy  AS p
                  WHERE s_from.id = a.s_from
                    AND s_from.id = p.state_id
                    AND a.name    = p.action_name
                    AND s_to.id   = a.s_to
                  GROUP BY a.s_from
                ) AS res(s_from, sum)
          WHERE s.id = res.s_from
        );

    DO $$
        BEGIN
            DROP TABLE IF EXISTS prev_policy CASCADE;
            CREATE TEMP TABLE prev_policy AS (TABLE policy);

            LOOP
                -- Keep current policy
                UPDATE prev_policy AS p
                   SET action_name = p_.action_name
                  FROM policy AS p_
                 WHERE p.state_id = p_.state_id;

                -- Calculate the new utility from the given current
                -- policy and utility.
                --
                -- This is the value determination in the modified policy
                -- iteration [Puterman & Shin, 1978].
                -- Specifically: Fixed number approximation with n = 1.
                -- Alternatively: Write a fixed number approximation with n > 1,
                -- dynamic number approximation or stabilizing utility values.
                UPDATE utility AS u
                   SET v = u_.v
                  FROM (SELECT s.id
                             , s.r + res.sum
                          FROM states AS s
                             , (SELECT a.s_from
                                     , sum(a.p * u.v) AS sum
                                  FROM states  AS s_from
                                     , states  AS s_to
                                     , actions AS a
                                     , policy  AS p
                                     , utility AS u
                                 WHERE s_from.id  = a.s_from
                                   AND s_from.id  = u.state_id
                                   AND a.name     = p.action_name
                                   AND s_to.id    = a.s_to
                                   AND u.state_id = a.s_to
                                 GROUP BY a.s_from
                               ) AS res(s_from, sum)
                         WHERE s.id = res.s_from
                       ) AS u_(state_id, v)
                 WHERE u.state_id = u_.state_id;

                -- Update policy based on the new utilities
                UPDATE policy AS p
                   SET action_name = p_.action_name
                  FROM (SELECT s.id
                             , next_actions.name
                          FROM states AS s
                             , LATERAL (SELECT ar.name
                                          FROM (SELECT a.name
                                                     , sum(a.p * u.v) AS v
                                                  FROM actions AS a
                                                     , utility AS u
                                                 WHERE s.id       = a.s_from
                                                   AND u.state_id = a.s_to
                                                 GROUP BY ( a.s_from
                                                          , a.name
                                                          )
                                               ) AS ar
                                         ORDER BY ar.v DESC
                                         LIMIT 1
                                       ) AS next_actions
                       ) AS p_(state_id, action_name)
                 WHERE p.state_id = p_.state_id;

                -- If previous policy is the same as the current policy, the
                -- approximation of the most optimal policy is done.
                EXIT WHEN NOT EXISTS ( TABLE prev_policy
                                         EXCEPT
                                       TABLE policy
                                     );
            END LOOP;
        END
    $$ LANGUAGE plpgsql;
    """,
    [ POINT_RANGE_X
    , POINT_RANGE_Y
    , WIDTH
    , HEIGHT
    , INACCESSIBLE_SQUARES
    ]
)

@to_compile
def walk( start_state: int
        , success_at:  int
        , failure_at:  int
        , max_steps:   int
        ) -> int:
    total_reward: float = 0.0
    curr_state:   int   = start_state
    curr_action:  str   = ''

    for step in range(1, max_steps+1):
        # Find the action the policy finds appropriate in
        # the current state
        curr_action = SQL(
            """
            SELECT p.action_name
              FROM policy AS p
                 , states AS s
             WHERE $1         = s.id
               AND p.state_id = s.id
            """,
            [ curr_state ]
        )

        # Random numer roll ∈ [0.0, 1.0)
        roll = random()

        # Find the state we actually reach. There may be a
        # chance we end up in another state.
        curr_state = SQL(
            """
            SELECT possible_moves.s_to
              FROM (SELECT a.s_to
                         , coalesce( sum(a.p)
                                     OVER (ORDER BY a.id
                                            ROWS BETWEEN unbounded preceding
                                                     AND 1 preceding
                                          )
                                   , 0.0
                                   ) AS p_from
                         , sum(a.p) OVER (ORDER BY a.id) AS p_to
                      FROM actions AS a
                     WHERE $1 = a.s_from
                       AND $2 = a.name
                   ) AS possible_moves(s_to, p_from, p_to)
             WHERE possible_moves.p_from <= $3
               AND possible_moves.p_to   >  $3
            """,
            [ curr_state
            , curr_action
            , roll
            ]
        )

        # Add the reward we receive by stepping on the state
        # we actually reached
        total_reward += SQL(
            """
            SELECT s.r
              FROM states AS s
             WHERE $1 = s.id
            """,
            [ curr_state ]
        )

        if total_reward >= success_at or total_reward <= failure_at:
            return round(step * copysign(1, total_reward))

    return 0


with open(Path(__file__).parent / "markov.sql") as f:
    DEFINE(f.read())

def walk_sql( start_state: int
            , success_at:  int
            , failure_at:  int
            , max_steps:   int
            ) -> float:
    return SQL( "SELECT walk_sql($1,$2,$3,$4);"
              , [ start_state
                , success_at
                , failure_at
                , max_steps
                ]
              )

def walk_plsql( start_state: int
              , success_at:  int
              , failure_at:  int
              , max_steps:   int
              ) -> float:
    return SQL( "SELECT walk_plsql($1,$2,$3,$4);"
              , [ start_state
                , success_at
                , failure_at
                , max_steps
                ]
              )

def walk_plpython( start_state: int
                 , success_at:  int
                 , failure_at:  int
                 , max_steps:   int
                 ) -> float:
    return SQL( "SELECT walk_plpython($1,$2,$3,$4);"
              , [ start_state
                , success_at
                , failure_at
                , max_steps
                ]
              )


if __name__ == "__main__":
    from math import floor
    from random import random
    from time import time

    ITERATIONS = 10
    SUCCESS_AT =   ITERATIONS * 5 // 6
    FAILURE_AT = - ITERATIONS * 3 // 4
    MAX_STEPS  = ITERATIONS
    ROBOTS     = ITERATIONS # ≡ invocations!

    starting_positions = SQL(
        """
        SELECT array_agg(id)
          FROM (SELECT i
                     , random()
                  FROM generate_series(1, $1) AS i
               ) AS _(i, roll)
             , LATERAL (SELECT s.id
                          FROM states AS s
                        OFFSET floor( roll
                                    * (SELECT count(*)
                                         FROM states
                                      )
                                    )
                         LIMIT 1
                        ) AS __(id)
        """,
        [ ROBOTS ]
    )

    funcs = {
        "python":   walk,
        "byepy":      walk_sql,
        "plpython": walk_plpython,
        "plsql":    walk_plsql,
    }

    for name, func in funcs.items():
        start = time()
        DO("SELECT setseed(0.42);")
        for pos in starting_positions:
            func(pos, SUCCESS_AT, FAILURE_AT, MAX_STEPS)
        end = time()
        print(name, (end - start) * 1000)

