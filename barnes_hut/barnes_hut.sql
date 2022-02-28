-- ByePy - Barnes-Hut Example
-- Copyright (C) 2022  Tim Fischer
--
-- barnes_hut.sql
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


CREATE OR REPLACE FUNCTION force_start(body bodies, 
                                       theta float8) RETURNS vec2f
AS
$$
    WITH RECURSIVE run("rec?",
                       "res",
                       "body",
                       "theta",
                       "G",
                       "node",
                       "Q",
                       "fx",
                       "fy",
                       "dist") AS
    (
        (SELECT "return1".*
         FROM LATERAL
              (SELECT "b"
                 FROM barneshut AS "b"
                WHERE "b"."node" = 0) AS "let0"("node_1"),
              LATERAL
              (SELECT True,
                      NULL :: vec2f,
                      "body",
                      "theta",
                      6.67e-11,
                      "node_1" :: barneshut,
                      ARRAY["node_1"] :: barneshut[] AS "Q_1",
                      0.0 :: float8,
                      0.0 :: float8,
                      NULL :: float8
              ) AS "return1")
          UNION ALL
        (SELECT "result".*
         FROM run AS "run"("rec?",
                           "res",
                           "body",
                           "theta",
                           "G",
                           "node",
                           "Q",
                           "fx",
                           "fy",
                           "dist"),
              LATERAL
              (SELECT "ifresult3".*
               FROM LATERAL
                    (SELECT (cardinality("Q")) > 0 AS "pred1_2") AS "let2"("pred1_2"),
                    LATERAL
                    ((SELECT "ifresult9".*
                      FROM LATERAL (SELECT ("Q")[1] AS "node_4") AS "let4"("node_4"),
                           LATERAL (SELECT ("Q")[2:] AS "Q_4") AS "let5"("Q_4"),
                           LATERAL
                           (SELECT greatest(sqrt( (("node_4" :: barneshut).x - ("body" :: bodies).x) ^ 2
                                                + (("node_4" :: barneshut).y - ("body" :: bodies).y) ^ 2),
                                            1.0e-10) AS "dist_3"
                           ) AS "let7"("dist_3"),
                           LATERAL
                           (SELECT ("node_4" :: barneshut).node IS NULL
                                OR ("node_4" :: barneshut).size / "dist_3" < "theta" AS "q6_3"
                           ) AS "let8"("q6_3"),
                           LATERAL
                           ((SELECT "ifresult12".*
                             FROM LATERAL
                                  (SELECT NOT EXISTS (SELECT 1 AS "?column?"
                                                      FROM walls AS "w"
                                                      WHERE ("_"."pos"    <= "_"."pos"    ## "w"."wall")
                                                         <> ("_"."center" <= "_"."center" ## "w"."wall")) AS "?column?"
                                   FROM (SELECT point(("body" :: bodies).x,
                                                      ("body" :: bodies).y) AS "point",
                                                point(("node_4" :: barneshut).x,
                                                      ("node_4" :: barneshut).y) AS "point"
                                        ) AS "_"("pos", "center")) AS "let11"("q11_5"),
                                  LATERAL
                                  ((SELECT "return16".*
                                    FROM LATERAL
                                         (SELECT "G" * ("body" :: bodies).mass * ("node_4" :: barneshut).mass / ("dist_3" ^ 2) AS "fac_6"
                                         ) AS "let13"("fac_6"),
                                         LATERAL
                                         (SELECT True,
                                                 NULL :: vec2f,
                                                 "body",
                                                 "theta",
                                                 "G",
                                                 "node_4",
                                                 "Q_4",
                                                 "fx" + (("node_4" :: barneshut).x - ("body" :: bodies).x) * "fac_6" AS "fx_7",
                                                 "fy" + (("node_4" :: barneshut).y - ("body" :: bodies).y) * "fac_6" AS "fy_7",
                                                 "dist_3"
                                         ) AS "return16"
                                    WHERE NOT "q11_5" IS DISTINCT FROM True)
                                     UNION ALL
                                   (SELECT True,
                                           NULL :: vec2f,
                                           "body",
                                           "theta",
                                           "G",
                                           "node_4",
                                           "Q_4",
                                           "fx",
                                           "fy",
                                           "dist_3"
                                    WHERE "q11_5" IS DISTINCT FROM True)
                                  ) AS "ifresult12"
                             WHERE NOT "q6_3" IS DISTINCT FROM True)
                              UNION ALL
                            (SELECT True,
                                    NULL :: vec2f,
                                    "body",
                                    "theta",
                                    "G",
                                    "node_4",
                                    "Q_4" || (SELECT array_agg("b")
                                                FROM barneshut AS "b"
                                               WHERE "b"."parent" = ("node_4" :: barneshut).node) AS "Q_6",
                                    "fx",
                                    "fy",
                                    "dist_3"
                             WHERE "q6_3" IS DISTINCT FROM True)
                           ) AS "ifresult9"
                      WHERE NOT "pred1_2" IS DISTINCT FROM True)
                       UNION ALL
                     (SELECT False,
                             ("fx", "fy") :: vec2f AS "result",
                             "run"."body",
                             "run"."theta",
                             "run"."G",
                             "run"."node",
                             "run"."Q",
                             "run"."fx",
                             "run"."fy",
                             "run"."dist"
                      WHERE "pred1_2" IS DISTINCT FROM True)
                    ) AS "ifresult3"
              ) AS "result"
         WHERE "run"."rec?")
    )
    SELECT "run"."res" AS "res"
    FROM run AS "run"
    WHERE NOT "run"."rec?"
$$ LANGUAGE SQL;


CREATE OR REPLACE FUNCTION force_plpython(body bodies, theta float8) RETURNS vec2f AS $$
    from math import sqrt

    # avoid duplicate plan preparation
    Q0 = SD.get('Q0')
    if Q0 is None:
        Q0 = plpy.prepare(
            "SELECT b AS node     "
            "  FROM barneshut AS b"
            " WHERE node = 0      "
        )
        SD['Q0'] = Q0
    Q1 = SD.get('Q1')
    if Q1 is None:
        Q1 = plpy.prepare(
            "SELECT NOT EXISTS (                          "
            "         SELECT 1                            "
            "           FROM walls AS w                   "
            "          WHERE (pos    <= pos    ## w.wall) "
            "             <> (center <= center ## w.wall) "
            "       ) AS exists                           "
            "  FROM (SELECT point( ($1 :: bodies   ).x    "
            "                    , ($1 :: bodies   ).y    "
            "                    ),                       "
            "               point( ($2 :: barneshut).x    "
            "                    , ($2 :: barneshut).y)   "
            "                    ) AS _(pos, center)      ",
            ["bodies", "barneshut"]
        )
        SD['Q1'] = Q1
    Q2 = SD.get('Q2')
    if Q2 is None:
        Q2 = plpy.prepare(
            "SELECT array_agg(b) :: barneshut[] AS children "
            "  FROM barneshut AS b                          "
            " WHERE b.parent = $1                           ",
            ["int4"]
        )
        SD['Q2'] = Q2

    # actual logic from here...
    G    = 6.67e-11                   # type: float
    node = Q0.execute([])[0]["node"]  # type: Barneshut
    Q    = [node]                     # type: list[Barneshut]
    fx   = 0.0                        # type: float
    fy   = 0.0                        # type: float

    while len(Q) > 0:
        node = Q.pop()
        dist = max(
            sqrt( (node["x"] - body["x"]) ** 2
                + (node["y"] - body["y"]) ** 2
                ),
            1e-10,
        )

        if node["node"] is None or node["size"] / dist < theta:
            if Q1.execute([body, node])[0]["exists"]:
                fac = G * body["mass"] * node["mass"] / (dist ** 2)
                fx += (node["x"] - body["x"]) * fac
                fy += (node["y"] - body["y"]) * fac
        else:
            Q.extend(Q2.execute([node["node"]])[0]["children"])

    return {
      "x": fx,
      "y": fy,
    }
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION force_plsql(body bodies, theta float8) RETURNS vec2f AS $$
  DECLARE
    G CONSTANT float8 := 6.67e-11;
    Q          barneshut[];
    node       barneshut;
    children   barneshut[];
    dist       float8;
    fx         float8 := 0.0;
    fy         float8 := 0.0;
    fac        float8;
  BEGIN
    node = (SELECT b
            FROM   barneshut AS b
            WHERE  b.node = 0);
    Q = array[node];

    WHILE cardinality(Q) > 0 LOOP
      node = Q[1];
      Q    = Q[2:];
      dist = GREATEST(
        sqrt((node.x - body.x)^2 + (node.y - body.y)^2),
        1e-10
      );

      IF (node.node IS NULL) OR (node.size / dist < theta) THEN
        IF (SELECT NOT EXISTS (
                    SELECT 1
                    FROM walls AS w
                    WHERE (pos    <= pos    ## w.wall)
                       <> (center <= center ## w.wall))
                FROM (SELECT point((body).x, (body).y),
                             point((node).x, (node).y)) AS _(pos, center))
        THEN
          fac = G * body.mass * node.mass / dist^2;
          fx  = fx + (node.x - body.x) * fac;
          fy  = fy + (node.y - body.y) * fac;
        END IF;
      ELSE
        children = (SELECT array_agg(b)
                    FROM   barneshut AS b
                    WHERE  b.parent = node.node);
        Q = Q || children;
      END IF;
    END LOOP;

    RETURN (fx, fy) :: vec2f;
  END;
$$ LANGUAGE plpgsql;