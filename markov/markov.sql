-- ByePy - Markov Robot Example
-- Copyright (C) 2022  Tim Fischer
--
-- markov.sql
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

CREATE OR REPLACE FUNCTION walk_sql(start_state int4,
                                    success_at int4,
                                    failure_at int4,
                                    max_steps int4) RETURNS float8
AS
$$
    WITH RECURSIVE run("rec?",
                       "res",
                       "start_state",
                       "success_at",
                       "failure_at",
                       "max_steps",
                       "total_reward",
                       "curr_state",
                       "step") AS
    (
        (SELECT True,
                NULL :: float8,
                "start_state",
                "success_at",
                "failure_at",
                "max_steps",
                0.0 :: float8,
                "start_state" AS "curr_state_1",
                1)
          UNION ALL
        (SELECT "result".*
         FROM run AS "run"("rec?",
                           "res",
                           "start_state",
                           "success_at",
                           "failure_at",
                           "max_steps",
                           "total_reward",
                           "curr_state",
                           "step"),
              LATERAL
              (SELECT "ifresult2".*
               FROM LATERAL
                    (SELECT "max_steps" + 1 AS "q2_2") AS "let0"("q2_2"),
                    LATERAL (SELECT "step" <= "q2_2" AS "pred1_2") AS "let1"("pred1_2"),
                    LATERAL
                    ((SELECT "ifresult10".*
                      FROM LATERAL
                           (SELECT "p"."action_name" AS "action_name"
                              FROM policy AS "p", states AS "s"
                             WHERE "curr_state"   = "s"."id"
                               AND "p"."state_id" = "s"."id") AS "let4"("curr_action_4"),
                           LATERAL (SELECT random()) AS "let_unfuck"("roll_3"),
                           LATERAL
                           (SELECT "possible_moves"."s_to" AS "s_to"
                              FROM (SELECT "a"."s_to" AS "s_to"
                                         , COALESCE(sum("a"."p") OVER (ORDER BY ("a"."id") ASC
                                                                        ROWS BETWEEN UNBOUNDED PRECEDING
                                                                                 AND 1 PRECEDING)
                                                   , 0.0) AS "p_from"
                                         , sum("a"."p") OVER(ORDER BY ("a"."id") ASC ) AS "p_to"
                                      FROM actions AS "a"
                                     WHERE "curr_state" = "a"."s_from"
                                       AND "curr_action_4" = "a"."name"
                                    ) AS "possible_moves"("s_to", "p_from", "p_to")
                              WHERE "possible_moves"."p_from" <= "roll_3"
                                AND "possible_moves"."p_to" > "roll_3") AS "let6"("curr_state_4"),
                           LATERAL
                           (SELECT "total_reward" + "s"."r" AS "r"
                              FROM states AS "s"
                             WHERE "curr_state_4" = "s"."id") AS "let8"("total_reward_4"),
                           LATERAL
                           (SELECT "total_reward_4" >= "success_at"
                                OR "total_reward_4" <= "failure_at" AS "q9_3"
                           ) AS "let9"("q9_3"),
                           LATERAL
                           ((SELECT False,
                                    "step" * sign("total_reward_4") AS "result",
                                    "run"."start_state",
                                    "run"."success_at",
                                    "run"."failure_at",
                                    "run"."max_steps",
                                    "run"."total_reward",
                                    "run"."curr_state",
                                    "run"."step"
                             WHERE NOT "q9_3" IS DISTINCT FROM True)
                              UNION ALL
                            (SELECT True,
                                    NULL :: float8,
                                    "start_state",
                                    "success_at",
                                    "failure_at",
                                    "max_steps",
                                    "total_reward_4",
                                    "curr_state_4",
                                    "step" + 1 AS "step_5"
                             WHERE "q9_3" IS DISTINCT FROM True)
                           ) AS "ifresult10"
                      WHERE NOT "pred1_2" IS DISTINCT FROM True)
                       UNION ALL
                     (SELECT False,
                             0.0 AS "result",
                             "run"."start_state",
                             "run"."success_at",
                             "run"."failure_at",
                             "run"."max_steps",
                             "run"."total_reward",
                             "run"."curr_state",
                             "run"."step"
                      WHERE "pred1_2" IS DISTINCT FROM True)
                    ) AS "ifresult2"
              ) AS "result"
         WHERE "run"."rec?")
    )
    SELECT "run"."res" AS "res"
    FROM run AS "run"
    WHERE NOT "run"."rec?"
$$ LANGUAGE SQL;


CREATE OR REPLACE FUNCTION walk_plpython( start_state int4
                                        , success_at  int4
                                        , failure_at  int4
                                        , max_steps   int4
                                        ) RETURNS int4 AS $$
    from math   import copysign, floor
    from random import random

    # avoid duplicate plan preparation
    Q0 = SD.get('Q0')
    if Q0 is None:
        Q0 = plpy.prepare(
            """
            SELECT p.action_name AS action
              FROM policy AS p
                 , states AS s
             WHERE $1         = s.id
               AND p.state_id = s.id
            """,
            ["int4"]
        )
        SD['Q0'] = Q0
    Q1 = SD.get('Q1')
    if Q1 is None:
        Q1 = plpy.prepare(
            """
            SELECT possible_moves.s_to AS state
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
            ["int4", "text", "float8"]
        )
        SD['Q1'] = Q1
    Q2 = SD.get('Q2')
    if Q2 is None:
        Q2 = plpy.prepare(
            """
            SELECT s.r AS reward
              FROM states AS s
             WHERE $1 = s.id
            """,
            ["int4"]
        )
        SD['Q2'] = Q2

    # actual logic from here...
    total_reward = 0.0
    curr_state   = start_state
    curr_action  = ''

    for step in range(1, max_steps+1):
        # Find the action the policy finds appropriate in
        # the current state
        curr_action = Q0.execute([curr_state])[0]["action"]

        # Random numer roll ∈ [0.0, 1.0)
        roll = random()

        # Find the state we actually reach. There may be a
        # chance we end up in another state.
        curr_state = Q1.execute([curr_state,curr_action,roll])[0]["state"]

        # Add the reward we receive by stepping on the state
        # we actually reached
        total_reward += Q2.execute([curr_state])[0]["reward"]

        if total_reward >= success_at or total_reward <= failure_at:
            return round(step * copysign(1, total_reward))

    return 0
$$ LANGUAGE plpython3u;


CREATE OR REPLACE FUNCTION walk_plsql(start_state int, success_at int, failure_at int, max_steps int)
RETURNS int AS $$
DECLARE
  total_reward int = 0;
  curr_state int = start_state;
  curr_action text = '';
  roll double precision;
BEGIN
  FOR steps in 1..max_steps LOOP
    -- Find the action the policy finds appropriate in the current state
    curr_action = (
      SELECT p.action_name
      FROM   policy AS p, states AS s
      WHERE  curr_state = s.id
      AND    p.state_id = s.id
    );
    -- Random number (double precision) roll ∈ [0.0, 1.0)
    roll = random();
    -- Find the state we actually reach. There may be a chance we end up in another state.
    curr_state = (
      SELECT possible_move.s_to
        FROM (
          SELECT a.s_to,
          COALESCE(SUM(a.p) OVER (ORDER BY a.id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0.0) AS p_from,
          SUM(a.p) OVER (ORDER BY a.id) AS p_to
          FROM  actions AS a
          WHERE curr_state  = a.s_from
          AND   curr_action = a.name
        ) AS possible_move(s_to, p_from, p_to)
      WHERE possible_move.p_from <= roll AND roll < possible_move.p_to
    );
    -- Add the reward we receive by stepping on the state we actually reached
    total_reward = total_reward + (
      SELECT s.r
      FROM   states AS s
      WHERE  curr_state = s.id
    );
    IF total_reward >= success_at OR total_reward <= failure_at THEN
      RETURN steps * sign(total_reward);
    END IF;
  END LOOP;
  RETURN 0;
END
$$ LANGUAGE PLPGSQL;