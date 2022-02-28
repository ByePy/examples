-- ByePy - Marching Squares Example
-- Copyright (C) 2022  Tim Fischer
--
-- march.sql
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

CREATE OR REPLACE FUNCTION march_start(start vec2i) RETURNS vec2i[]
AS
$$
    WITH RECURSIVE run("rec?",
                       "res",
                       "start",
                       "goal",
                       "track",
                       "march",
                       "current",
                       "dir") AS
    (
        (SELECT True,
                NULL :: vec2i[],
                "start",
                NULL :: vec2i,
                False,
                ARRAY[] :: vec2i[],
                "start" AS "current_1",
                NULL :: directions)
          UNION ALL
        (SELECT "result".*
         FROM run AS "run"("rec?",
                           "res",
                           "start",
                           "goal",
                           "track",
                           "march",
                           "current",
                           "dir"),
              LATERAL
              (SELECT "ifresult1".*
               FROM LATERAL
                    (SELECT ("track" AND "current" = "goal") AS "q4_2"
                    ) AS "let0"("q4_2"),
                    LATERAL
                    ((SELECT False,
                             "march" AS "result",
                             "run"."start",
                             "run"."goal",
                             "run"."track",
                             "run"."march",
                             "run"."current",
                             "run"."dir"
                      WHERE NOT "q4_2" IS DISTINCT FROM True)
                       UNION ALL
                     (SELECT "ifresult8".*
                      FROM LATERAL
                           (SELECT "s" AS "s"
                              FROM squares AS "s"
                             WHERE "s"."xy" = "current"
                           ) AS "let4"("square_3"),
                           LATERAL
                           (SELECT "d" AS "d"
                              FROM directions AS "d"
                             WHERE ("square_3" :: squares).ll = "d"."ll"
                               AND ("square_3" :: squares).lr = "d"."lr"
                               AND ("square_3" :: squares).ul = "d"."ul"
                               AND ("square_3" :: squares).ur = "d"."ur"
                           ) AS "let6"("dir_3"),
                           LATERAL
                           (SELECT (NOT "track" AND ("dir_3" :: directions).track) AS "q10_3"
                           ) AS "let7"("q10_3"),
                           LATERAL
                           ((SELECT True,
                                    NULL :: vec2i[],
                                    "start",
                                    "current" AS "goal_5",
                                    True,
                                    "march" || "current" AS "march_8",
                                    ( ("current" :: vec2i).x + (("dir_3" :: directions).dir :: vec2i).x
                                    , ("current" :: vec2i).y + (("dir_3" :: directions).dir :: vec2i).y
                                    ) :: vec2i AS "current_7",
                                    "dir_3"
                             WHERE NOT "q10_3" IS DISTINCT FROM True)
                              UNION ALL
                            (SELECT "ifresult18".*
                             FROM LATERAL
                                  ((SELECT True,
                                           NULL :: vec2i[],
                                           "start",
                                           "goal",
                                           "track",
                                           "march" || "current" AS "march_8",
                                           ( ("current" :: vec2i).x + (("dir_3" :: directions).dir :: vec2i).x
                                           , ("current" :: vec2i).y + (("dir_3" :: directions).dir :: vec2i).y
                                           ) :: vec2i AS "current_7",
                                           "dir_3"
                                    WHERE NOT "track" IS DISTINCT FROM True)
                                     UNION ALL
                                   (SELECT True,
                                           NULL :: vec2i[],
                                           "start",
                                           "goal",
                                           "track",
                                           "march",
                                           ( ("current" :: vec2i).x + (("dir_3" :: directions).dir :: vec2i).x
                                           , ("current" :: vec2i).y + (("dir_3" :: directions).dir :: vec2i).y
                                           ) :: vec2i AS "current_7",
                                           "dir_3"
                                    WHERE "track" IS DISTINCT FROM True)
                                  ) AS "ifresult18"
                             WHERE "q10_3" IS DISTINCT FROM True)
                           ) AS "ifresult8"
                      WHERE "q4_2" IS DISTINCT FROM True)
                    ) AS "ifresult1"
              ) AS "result"
         WHERE "run"."rec?")
    )
    SELECT "run"."res" AS "res"
    FROM run AS "run"
    WHERE NOT "run"."rec?"
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION march_plpython(start vec2i) RETURNS vec2i[] AS $$
    # avoid duplicate plan preparation
    Q0 = SD.get('Q0')
    if Q0 is None:
        Q0 = plpy.prepare(
            "SELECT s :: squares AS square"
            "  FROM squares AS s"
            " WHERE s.xy = $1",
            ["vec2i"]
        )
        SD['Q0'] = Q0
    Q1 = SD.get('Q1')
    if Q1 is None:
        Q1 = plpy.prepare(
            "SELECT d :: directions AS dir"
            "  FROM directions AS d"
            " WHERE (($1 :: squares).ll, ($1 :: squares).lr, ($1 :: squares).ul, ($1 :: squares).ur)"
            "     = (d.ll, d.lr, d.ul, d.ur)",
            ["squares"]
        )
        SD['Q1'] = Q1

    # actual logic from here...
    goal    = None   # type: Vec2i
    track   = False  # type: bool
    march   = []     # type: list[Vec2i]
    current = start  # type: Vec2i

    while True:
        if track and current == goal:
            break

        square = Q0.execute([current])[0]["square"]
        dir    = Q1.execute([square])[0]["dir"]

        if not track and dir["track"]:
            track = True
            goal = current
        if track:
            march.append(current)

        current = {
            "x": current["x"] + dir["dir"]["x"],
            "y": current["y"] + dir["dir"]["y"]
        }

    return march
$$ LANGUAGE plpython3u;


CREATE OR REPLACE FUNCTION march_plsql(start vec2i) RETURNS vec2i[] AS $$
  DECLARE
    track    boolean  := false;
    goal     vec2i;
    march    vec2i[]  := array[] :: vec2i[];
    current  vec2i    := start;
    square   squares;
    dir      directions;
  BEGIN
    WHILE true LOOP
      IF track AND current = goal THEN
        EXIT;
      END IF;

      square := (SELECT s :: squares
                   FROM squares AS s
                  WHERE s.xy = current);
      dir    := (SELECT d :: directions
                   FROM directions AS d
                  WHERE square.ll = d.ll
                    AND square.lr = d.lr
                    AND square.ul = d.ul
                    AND square.ur = d.ur);

      IF NOT track AND dir.track THEN
        track := true;
        goal  := current;
      END IF;
      IF track THEN
        march := march || current;
      END IF;

      current := (current.x + (dir.dir).x, current.y + (dir.dir).y) :: vec2i;
    END LOOP;

    RETURN march;
  END;
$$ LANGUAGE plpgsql;