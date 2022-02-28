-- ByePy - Simple VM Example
-- Copyright (C) 2022  Tim Fischer
--
-- vm.sql
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

CREATE OR REPLACE FUNCTION run_start(regs int4[]) RETURNS int4
AS
$$
    WITH RECURSIVE run("rec?", 
                       "res", 
                       "regs", 
                       "ip",
                       "ins") AS
    (
        (SELECT True,
                NULL :: int4,
                "regs",
                0,
                NULL :: instruction)
          UNION ALL
        (SELECT "result".*
         FROM run AS "run"("rec?",
                           "res",
                           "regs",
                           "ip",
                           "ins"),
              LATERAL
              (SELECT "ifresult4".*
               FROM LATERAL
                    (SELECT ("p") :: instruction AS "p"
                     FROM program AS "p"
                     WHERE "p"."loc" = "ip") AS "let1"("ins_2"),
                    LATERAL (SELECT "ip" + 1 AS "ip_3") AS "let2"("ip_3"),
                    LATERAL
                    (SELECT (("ins_2" :: instruction).opc) = 'lod' AS "q5_2"
                    ) AS "let3"("q5_2"),
                    LATERAL
                    ((SELECT True,
                             NULL :: int4,
                             (("regs")[1:("ins_2" :: instruction).reg1])
                             ||
                             ((("ins_2" :: instruction).reg2)
                              ||
                              (("regs")[(("ins_2" :: instruction).reg1) + 2:])) AS "regs_27",
                             "ip_3",
                             "ins_2"
                      WHERE NOT "q5_2" IS DISTINCT FROM True)
                       UNION ALL
                     (SELECT "ifresult8".*
                      FROM LATERAL
                           (SELECT (("ins_2" :: instruction).opc) = 'mov' AS "q9_3"
                           ) AS "let7"("q9_3"),
                           LATERAL
                           ((SELECT True,
                                    NULL :: int4,
                                    (("regs")[1:("ins_2" :: instruction).reg1])
                                    ||
                                    ((("regs")[(("ins_2" :: instruction).reg2) + 1])
                                     ||
                                     (("regs")[(("ins_2" :: instruction).reg1)
                                               +
                                               2:])) AS "regs_25",
                                    "ip_3",
                                    "ins_2"
                             WHERE NOT "q9_3" IS DISTINCT FROM True)
                              UNION ALL
                            (SELECT "ifresult12".*
                             FROM LATERAL
                                  (SELECT (("ins_2" :: instruction).opc) = 'jeq' AS "q13_4"
                                  ) AS "let11"("q13_4"),
                                  LATERAL
                                  ((SELECT "ifresult14".*
                                    FROM LATERAL
                                         (SELECT (("regs")[(("ins_2" :: instruction).reg1) + 1])
                                                 =
                                                 (("regs")[(("ins_2" :: instruction).reg2)
                                                           +
                                                           1]) AS "q17_18"
                                         ) AS "let13"("q17_18"),
                                         LATERAL
                                         ((SELECT True,
                                                  NULL :: int4,
                                                  "regs",
                                                  ("ins_2" :: instruction).reg3 AS "ip_22",
                                                  "ins_2"
                                           WHERE NOT "q17_18" IS DISTINCT FROM True)
                                            UNION ALL
                                          (SELECT True, NULL :: int4, "regs", "ip_3", "ins_2"
                                           WHERE "q17_18" IS DISTINCT FROM True)
                                         ) AS "ifresult14"
                                    WHERE NOT "q13_4" IS DISTINCT FROM True)
                                     UNION ALL
                                   (SELECT "ifresult19".*
                                    FROM LATERAL
                                         (SELECT (("ins_2" :: instruction).opc) = 'jmp' AS "q21_5"
                                         ) AS "let18"("q21_5"),
                                         LATERAL
                                         ((SELECT True,
                                                  NULL :: int4,
                                                  "regs",
                                                  ("ins_2" :: instruction).reg1 AS "ip_19",
                                                  "ins_2"
                                           WHERE NOT "q21_5" IS DISTINCT FROM True)
                                            UNION ALL
                                          (SELECT "ifresult23".*
                                           FROM LATERAL
                                                (SELECT (("ins_2" :: instruction).opc)
                                                        =
                                                        'add' AS "q25_6"
                                                ) AS "let22"("q25_6"),
                                                LATERAL
                                                ((SELECT True,
                                                         NULL :: int4,
                                                         (("regs")[1:("ins_2" :: instruction).reg1])
                                                         ||
                                                         (((("regs")[(("ins_2" :: instruction).reg2)
                                                                     +
                                                                     1])
                                                           +
                                                           (("regs")[(("ins_2" :: instruction).reg3)
                                                                     +
                                                                     1]))
                                                          ||
                                                          (("regs")[(("ins_2" :: instruction).reg1)
                                                                    +
                                                                    2:])) AS "regs_20",
                                                         "ip_3",
                                                         "ins_2"
                                                  WHERE NOT "q25_6" IS DISTINCT FROM True)
                                                   UNION ALL
                                                 (SELECT "ifresult27".*
                                                  FROM LATERAL
                                                       (SELECT (("ins_2" :: instruction).opc)
                                                               =
                                                               'sub' AS "q29_7"
                                                       ) AS "let26"("q29_7"),
                                                       LATERAL
                                                       ((SELECT True,
                                                                NULL :: int4,
                                                                (("regs")[1:("ins_2" :: instruction).reg1])
                                                                ||
                                                                (((("regs")[(("ins_2" :: instruction).reg2)
                                                                            +
                                                                            1])
                                                                  -
                                                                  (("regs")[(("ins_2" :: instruction).reg3)
                                                                            +
                                                                            1]))
                                                                 ||
                                                                 (("regs")[(("ins_2" :: instruction).reg1)
                                                                           +
                                                                           2:])) AS "regs_18",
                                                                "ip_3",
                                                                "ins_2"
                                                         WHERE NOT "q29_7" IS DISTINCT FROM True)
                                                          UNION ALL
                                                        (SELECT "ifresult31".*
                                                         FROM LATERAL
                                                              (SELECT (("ins_2" :: instruction).opc)
                                                                      =
                                                                      'mul' AS "q33_8"
                                                              ) AS "let30"("q33_8"),
                                                              LATERAL
                                                              ((SELECT True,
                                                                       NULL :: int4,
                                                                       (("regs")[1:("ins_2" :: instruction).reg1])
                                                                       ||
                                                                       (((("regs")[(("ins_2" :: instruction).reg2)
                                                                                   +
                                                                                   1])
                                                                         *
                                                                         (("regs")[(("ins_2" :: instruction).reg3)
                                                                                   +
                                                                                   1]))
                                                                        ||
                                                                        (("regs")[(("ins_2" :: instruction).reg1)
                                                                                  +
                                                                                  2:])) AS "regs_16",
                                                                       "ip_3",
                                                                       "ins_2"
                                                                WHERE NOT "q33_8"
                                                                          IS DISTINCT FROM
                                                                          True)
                                                                 UNION ALL
                                                               (SELECT "ifresult35".*
                                                                FROM LATERAL
                                                                     (SELECT (("ins_2" :: instruction).opc)
                                                                             =
                                                                             'div' AS "q37_9"
                                                                     ) AS "let34"("q37_9"),
                                                                     LATERAL
                                                                     ((SELECT True,
                                                                              NULL :: int4,
                                                                              (("regs")[1:("ins_2" :: instruction).reg1])
                                                                              ||
                                                                              (((("regs")[(("ins_2" :: instruction).reg2)
                                                                                          +
                                                                                          1])
                                                                                /
                                                                                (("regs")[(("ins_2" :: instruction).reg3)
                                                                                          +
                                                                                          1]))
                                                                               ||
                                                                               (("regs")[(("ins_2" :: instruction).reg1)
                                                                                         +
                                                                                         2:])) AS "regs_14",
                                                                              "ip_3",
                                                                              "ins_2"
                                                                       WHERE NOT "q37_9"
                                                                                 IS DISTINCT FROM
                                                                                 True)
                                                                        UNION ALL
                                                                      (SELECT "ifresult39".*
                                                                       FROM LATERAL
                                                                            (SELECT (("ins_2" :: instruction).opc)
                                                                                    =
                                                                                    'mod' AS "q41_10"
                                                                            ) AS "let38"("q41_10"),
                                                                            LATERAL
                                                                            ((SELECT True,
                                                                                     NULL :: int4,
                                                                                     (("regs")[1:("ins_2" :: instruction).reg1])
                                                                                     ||
                                                                                     (((("regs")[(("ins_2" :: instruction).reg2)
                                                                                                 +
                                                                                                 1])
                                                                                       %
                                                                                       (("regs")[(("ins_2" :: instruction).reg3)
                                                                                                 +
                                                                                                 1]))
                                                                                      ||
                                                                                      (("regs")[(("ins_2" :: instruction).reg1)
                                                                                                +
                                                                                                2:])) AS "regs_12",
                                                                                     "ip_3",
                                                                                     "ins_2"
                                                                              WHERE NOT "q41_10"
                                                                                        IS DISTINCT FROM
                                                                                        True)
                                                                               UNION ALL
                                                                             (SELECT "ifresult43".*
                                                                              FROM LATERAL
                                                                                   (SELECT (("ins_2" :: instruction).opc)
                                                                                           =
                                                                                           'hlt' AS "q45_11"
                                                                                   ) AS "let42"("q45_11"),
                                                                                   LATERAL
                                                                                   ((SELECT False,
                                                                                            ("regs")[(("ins_2" :: instruction).reg1)
                                                                                                     +
                                                                                                     1] AS "result",
                                                                                            "run"."regs",
                                                                                            "run"."ip",
                                                                                            "run"."ins"
                                                                                     WHERE NOT "q45_11"
                                                                                               IS DISTINCT FROM
                                                                                               True)
                                                                                      UNION ALL
                                                                                    (SELECT True,
                                                                                            NULL :: int4,
                                                                                            "regs",
                                                                                            "ip_3",
                                                                                            "ins_2"
                                                                                     WHERE "q45_11"
                                                                                           IS DISTINCT FROM
                                                                                           True)
                                                                                   ) AS "ifresult43"
                                                                              WHERE "q41_10"
                                                                                    IS DISTINCT FROM
                                                                                    True)
                                                                            ) AS "ifresult39"
                                                                       WHERE "q37_9"
                                                                             IS DISTINCT FROM
                                                                             True)
                                                                     ) AS "ifresult35"
                                                                WHERE "q33_8" IS DISTINCT FROM True)
                                                              ) AS "ifresult31"
                                                         WHERE "q29_7" IS DISTINCT FROM True)
                                                       ) AS "ifresult27"
                                                  WHERE "q25_6" IS DISTINCT FROM True)
                                                ) AS "ifresult23"
                                           WHERE "q21_5" IS DISTINCT FROM True)
                                         ) AS "ifresult19"
                                    WHERE "q13_4" IS DISTINCT FROM True)
                                  ) AS "ifresult12"
                             WHERE "q9_3" IS DISTINCT FROM True)
                           ) AS "ifresult8"
                      WHERE "q5_2" IS DISTINCT FROM True)
                    ) AS "ifresult4"
              ) AS "result"
         WHERE "run"."rec?")
    )
    SELECT "run"."res" AS "res"
    FROM run AS "run"
    WHERE NOT "run"."rec?"
$$ LANGUAGE SQL;