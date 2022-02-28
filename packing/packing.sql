-- ByePy - TPC-H Packing Example
-- Copyright (C) 2022  Tim Fischer
--
-- packing.sql
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

WITH RECURSIVE run("rec?",
                   "label",
                   "res",
                   "orderkey",
                   "capacity",
                   "n",
                   "packs",
                   "items",
                   "max_size",
                   "max_subset",
                   "subset",
                   "size",
                   "pack",
                   "linenumber") AS
(
    (SELECT "ifresult29".*
     FROM LATERAL
          (SELECT (count(*)) :: int4 AS "count"
                   FROM lineitem AS "l"
                   WHERE "l"."l_orderkey" = $1) AS "let26"("n_1"),
          LATERAL
          (SELECT ("n_1" = 0 OR $2 < (SELECT max("p"."p_size") AS "max"
                                      FROM lineitem AS "l", part AS "p"
                                      WHERE ("l"."l_orderkey" = $1
                                             AND
                                             "l"."l_partkey" = "p"."p_partkey"))) AS "q5_1"
          ) AS "let28"("q5_1"),
          LATERAL
          ((SELECT False,
                   NULL :: text,
                   ARRAY[] :: int4[][] AS "result",
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4[][],
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4[],
                   NULL :: int4
            WHERE NOT "q5_1" IS DISTINCT FROM True)
             UNION ALL
           (SELECT True,
                   'while6_head',
                   NULL :: int4[][],
                   $1,
                   $2,
                   "n_1",
                   ARRAY[] :: int4[][],
                   (1 << "n_1") - 1 AS "items_2",
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4,
                   NULL :: int4[],
                   NULL :: int4
            WHERE "q5_1" IS DISTINCT FROM True)
          ) AS "ifresult29")
      UNION ALL
    (SELECT "result".*
     FROM run AS "run"("rec?",
                       "label",
                       "res",
                       "orderkey",
                       "capacity",
                       "n",
                       "packs",
                       "items",
                       "max_size",
                       "max_subset",
                       "subset",
                       "size",
                       "pack",
                       "linenumber"),
          LATERAL
          ((SELECT "ifresult2".*
            FROM LATERAL
                 (SELECT "linenumber" <= "n" AS "pred19_9") AS "let1"("pred19_9"),
                 LATERAL
                 ((SELECT True,
                          'for18_head',
                          NULL :: int4[][],
                          "orderkey",
                          "capacity",
                          "n",
                          "packs",
                          "items",
                          "max_size",
                          "max_subset",
                          "subset",
                          "size",
                          "pack"
                          ||
                          (CASE WHEN ("max_subset" & (1 << "linenumber"))
                                     <>
                                     0 THEN "linenumber" + 1
                                ELSE 0
                          END) AS "pack_11",
                          "linenumber" + 1 AS "linenumber_11"
                   WHERE NOT "pred19_9" IS DISTINCT FROM True)
                    UNION ALL
                  (SELECT True,
                          'while6_head',
                          NULL :: int4[][],
                          "orderkey",
                          "capacity",
                          "n",
                          "packs" || (ARRAY["pack"] :: int4[][]) AS "packs_12",
                          "items" & (~ "max_subset") AS "items_12",
                          "max_size",
                          "max_subset",
                          "subset",
                          "size",
                          "pack",
                          "linenumber"
                   WHERE "pred19_9" IS DISTINCT FROM True)
                 ) AS "ifresult2"
            WHERE "run"."label" = 'for18_head')
             UNION ALL
           ((SELECT "ifresult12".*
             FROM LATERAL
                  (SELECT (sum("p"."p_size")) :: int4 AS "sum"
                   FROM lineitem AS "l", part AS "p"
                   WHERE ("l"."l_orderkey" = "orderkey"
                          AND
                          ("subset" & (1 << ("l"."l_linenumber" - 1))) <> 0
                          AND
                          "l"."l_partkey" = "p"."p_partkey")) AS "let10"("size_5"),
                  LATERAL
                  (SELECT ("size_5" <= "capacity" AND "size_5" > "max_size") AS "q13_5"
                  ) AS "let11"("q13_5"),
                  LATERAL
                  ((SELECT "ifresult16".*
                    FROM LATERAL (SELECT "subset" = "items" AS "q17_6") AS "let15"("q17_6"),
                         LATERAL
                         ((SELECT True,
                                  'for18_head',
                                  NULL :: int4[][],
                                  "orderkey",
                                  "capacity",
                                  "n",
                                  "packs",
                                  "items",
                                  "size_5" AS "max_size_13",
                                  "subset" AS "max_subset_13",
                                  "subset",
                                  "size_5",
                                  ARRAY[] :: int4[],
                                  0
                           WHERE NOT "q17_6" IS DISTINCT FROM True)
                            UNION ALL
                          (SELECT True,
                                  'loop8_body',
                                  NULL :: int4[][],
                                  "orderkey",
                                  "capacity",
                                  "n",
                                  "packs",
                                  "items",
                                  "size_5" AS "max_size_13",
                                  "subset" AS "max_subset_13",
                                  "items" & ("subset" - "items") AS "subset_8",
                                  "size_5",
                                  "pack",
                                  "linenumber"
                           WHERE "q17_6" IS DISTINCT FROM True)
                         ) AS "ifresult16"
                    WHERE NOT "q13_5" IS DISTINCT FROM True)
                     UNION ALL
                   (SELECT "ifresult21".*
                    FROM LATERAL
                         (SELECT "subset" = "items" AS "q17_6") AS "let20"("q17_6"),
                         LATERAL
                         ((SELECT True,
                                  'for18_head',
                                  NULL :: int4[][],
                                  "orderkey",
                                  "capacity",
                                  "n",
                                  "packs",
                                  "items",
                                  "max_size",
                                  "max_subset",
                                  "subset",
                                  "size_5",
                                  ARRAY[] :: int4[],
                                  0
                           WHERE NOT "q17_6" IS DISTINCT FROM True)
                            UNION ALL
                          (SELECT True,
                                  'loop8_body',
                                  NULL :: int4[][],
                                  "orderkey",
                                  "capacity",
                                  "n",
                                  "packs",
                                  "items",
                                  "max_size",
                                  "max_subset",
                                  "items" & ("subset" - "items") AS "subset_8",
                                  "size_5",
                                  "pack",
                                  "linenumber"
                           WHERE "q17_6" IS DISTINCT FROM True)
                         ) AS "ifresult21"
                    WHERE "q13_5" IS DISTINCT FROM True)
                  ) AS "ifresult12"
             WHERE "run"."label" = 'loop8_body')
             UNION ALL
           (SELECT "ifresult34".*
            FROM LATERAL
                 (SELECT "items" <> 0 AS "pred7_3") AS "let33"("pred7_3"),
                 LATERAL
                 ((SELECT True,
                          'loop8_body',
                          NULL :: int4[][],
                          "orderkey",
                          "capacity",
                          "n",
                          "packs",
                          "items",
                          0,
                          0,
                          "items" & (- "items") AS "subset_4",
                          "size",
                          "pack",
                          "linenumber"
                   WHERE NOT "pred7_3" IS DISTINCT FROM True)
                    UNION ALL
                  (SELECT False,
                          NULL :: text,
                          "packs" AS "result",
                          "run"."orderkey",
                          "run"."capacity",
                          "run"."n",
                          "run"."packs",
                          "run"."items",
                          "run"."max_size",
                          "run"."max_subset",
                          "run"."subset",
                          "run"."size",
                          "run"."pack",
                          "run"."linenumber"
                   WHERE "pred7_3" IS DISTINCT FROM True)
                 ) AS "ifresult34"
            WHERE "run"."label" = 'while6_head'))
          ) AS "result"("rec?",
                        "label",
                        "res",
                        "orderkey",
                        "capacity",
                        "n",
                        "packs",
                        "items",
                        "max_size",
                        "max_subset",
                        "subset",
                        "size",
                        "pack",
                        "linenumber")
     WHERE "run"."rec?")
)
SELECT "run"."res" AS "res"
FROM run AS "run"
WHERE NOT "run"."rec?"