-- ByePy - TPC-H Savings Example
-- Copyright (C) 2022  Tim Fischer
--
-- savings.sql
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

CREATE OR REPLACE FUNCTION savings_start(orderkey int4) RETURNS savings
AS
$$
    WITH RECURSIVE run("rec?", 
                       "res",
                       "orderkey",
                       "items",
                       "total_supplycost",
                       "new_supplycost",
                       "new_suppliers",
                       "item",
                       "lineitem",
                       "partsupp",
                       "min_supplycost",
                       "new_supplier") AS
    (
        (SELECT "ifresult26".*
         FROM LATERAL
              (SELECT "o" AS "o"
               FROM orders AS "o"
               WHERE "o"."o_orderkey" = "orderkey") AS "let24"("order_1"),
              LATERAL (SELECT "order_1" IS NULL AS "q4_1") AS "let25"("q4_1"),
              LATERAL
              ((SELECT False,
                       NULL :: savings AS "result",
                       NULL :: int4,
                       NULL :: int4,
                       NULL :: float8,
                       NULL :: float8,
                       NULL :: supplierchange[],
                       NULL :: int4,
                       NULL :: lineitem,
                       NULL :: partsupp,
                       NULL :: float8,
                       NULL :: int4
                WHERE NOT "q4_1" IS DISTINCT FROM True)
                 UNION ALL
               (SELECT True,
                       NULL :: savings,
                       "orderkey",
                       (SELECT count(*) :: int4 AS "count"
                          FROM lineitem AS "l"
                         WHERE "l"."l_orderkey" = "orderkey") AS "items_2",
                       0.0,
                       0.0,
                       ARRAY[] :: supplierchange[],
                       1,
                       NULL :: lineitem,
                       NULL :: partsupp,
                       NULL :: float8,
                       NULL :: int4
                WHERE "q4_1" IS DISTINCT FROM True)
              ) AS "ifresult26")
          UNION ALL
        (SELECT "result".*
         FROM run AS "run"("rec?",
                           "res",
                           "orderkey",
                           "items",
                           "total_supplycost",
                           "new_supplycost",
                           "new_suppliers",
                           "item",
                           "lineitem",
                           "partsupp",
                           "min_supplycost",
                           "new_supplier"),
              LATERAL
              (SELECT "ifresult2".*
               FROM LATERAL
                    (SELECT "item" <= "items" + 1 AS "pred7_3") AS "let1"("pred7_3"),
                    LATERAL
                    ((SELECT "ifresult12".*
                      FROM LATERAL
                           (SELECT (SELECT "l" AS "l"
                                      FROM lineitem AS "l"
                                     WHERE "l"."l_orderkey"   = "orderkey"
                                       AND "l"."l_linenumber" = "item")) AS "let4"("lineitem_4"),
                           LATERAL
                           (SELECT (SELECT "ps" AS "ps"
                                      FROM partsupp AS "ps"
                                     WHERE ("lineitem_4" :: lineitem).l_partkey = "ps"."ps_partkey"
                                       AND ("lineitem_4" :: lineitem).l_suppkey = "ps"."ps_suppkey")) AS "let6"("partsupp_4"),
                           LATERAL
                           (SELECT min("ps"."ps_supplycost") :: float8 AS "min"
                              FROM partsupp AS "ps"
                             WHERE "ps"."ps_partkey"  =  ("lineitem_4" :: lineitem).l_partkey
                               AND "ps"."ps_availqty" >= ("lineitem_4" :: lineitem).l_quantity) AS "let8"("min_supplycost_4"),
                           LATERAL
                           (SELECT min("ps"."ps_suppkey") AS "min"
                              FROM partsupp AS "ps"
                             WHERE "ps"."ps_supplycost" = "min_supplycost_4"
                               AND "ps"."ps_partkey"    = ("lineitem_4" :: lineitem).l_partkey) AS "let10"("new_supplier_4"),
                           LATERAL
                           (SELECT "new_supplier_4" <> ("partsupp_4" :: partsupp).ps_suppkey) AS "let11"("q16_4"),
                           LATERAL
                           ((SELECT True,
                                    NULL :: savings,
                                    "orderkey",
                                    "items",
                                    "total_supplycost"
                                    + ("partsupp_4" :: partsupp).ps_supplycost
                                    * ("lineitem_4" :: lineitem).l_quantity AS "total_supplycost_7",
                                    "new_supplycost"
                                    + "min_supplycost_4"
                                    * ("lineitem_4" :: lineitem).l_quantity AS "new_supplycost_7",
                                    "new_suppliers" || ( ("lineitem_4" :: lineitem).l_partkey
                                                       , ("partsupp_4" :: partsupp).ps_suppkey
                                                       , "new_supplier_4"
                                                       ) :: supplierchange AS "new_suppliers_6",
                                    "item" + 1,
                                    "lineitem_4",
                                    "partsupp_4",
                                    "min_supplycost_4",
                                    "new_supplier_4"
                             WHERE NOT "q16_4" IS DISTINCT FROM True)
                              UNION ALL
                            (SELECT True,
                                    NULL :: savings,
                                    "orderkey",
                                    "items",
                                    "total_supplycost"
                                    + ("partsupp_4" :: partsupp).ps_supplycost
                                    * ("lineitem_4" :: lineitem).l_quantity AS "total_supplycost_7",
                                    "new_supplycost"
                                    + "min_supplycost_4"
                                    * ("lineitem_4" :: lineitem).l_quantity AS "new_supplycost_7",
                                    "new_suppliers",
                                    "item" + 1 AS "item_7",
                                    "lineitem_4",
                                    "partsupp_4",
                                    "min_supplycost_4",
                                    "new_supplier_4"
                             WHERE "q16_4" IS DISTINCT FROM True)
                           ) AS "ifresult12"
                      WHERE NOT "pred7_3" IS DISTINCT FROM True)
                       UNION ALL
                     (SELECT False,
                             ( (1 - ("new_supplycost" / "total_supplycost")) * 100.0
                             , "new_suppliers"
                             ) :: savings AS "result",
                             "run"."orderkey",
                             "run"."items",
                             "run"."total_supplycost",
                             "run"."new_supplycost",
                             "run"."new_suppliers",
                             "run"."item",
                             "run"."lineitem",
                             "run"."partsupp",
                             "run"."min_supplycost",
                             "run"."new_supplier"
                      WHERE "pred7_3" IS DISTINCT FROM True)
                    ) AS "ifresult2"
              ) AS "result"
         WHERE "run"."rec?")
    )
    SELECT "run"."res" AS "res"
    FROM run AS "run"
    WHERE NOT "run"."rec?"
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION savings_plpython(orderkey int4) RETURNS savings AS $$
    # avoid duplicate plan preparation
    Q0 = SD.get('Q0')
    if Q0 is None:
        Q0 = plpy.prepare(
            "SELECT o :: orders AS order"
            "  FROM orders as o"
            " WHERE o.o_orderkey = $1",
            ["int4"]
        )
        SD['Q0'] = Q0
    Q1 = SD.get('Q1')
    if Q1 is None:
        Q1 = plpy.prepare(
            "SELECT count(*) :: int4 AS \"#items\""
            "  FROM lineitem AS l"
            " WHERE l.l_orderkey = $1",
            ["int4"]
        )
        SD['Q1'] = Q1
    Q2 = SD.get('Q2')
    if Q2 is None:
        Q2 = plpy.prepare(
            "SELECT l :: lineitem As lineitem"
            "  FROM lineitem AS l"
            " WHERE l.l_orderkey   = $1"
            "   AND l.l_linenumber = $2",
            ["int4", "int4"]
        )
        SD['Q2'] = Q2
    Q3 = SD.get('Q3')
    if Q3 is None:
        Q3 = plpy.prepare(
            "SELECT ps :: partsupp AS partsupp"
            "  FROM partsupp AS ps"
            " WHERE ($1 :: lineitem).l_partkey = ps.ps_partkey"
            "   AND ($1 :: lineitem).l_suppkey = ps.ps_suppkey",
            ["lineitem"]
        )
        SD['Q3'] = Q3
    Q4 = SD.get('Q4')
    if Q4 is None:
        Q4 = plpy.prepare(
            "SELECT min(ps.ps_supplycost) :: float AS \"min cost\""
            "  FROM partsupp AS ps"
            " WHERE ps.ps_partkey  =  ($1 :: lineitem).l_partkey"
            "   AND ps.ps_availqty >= ($1 :: lineitem).l_quantity",
            ["lineitem"]
        )
        SD['Q4'] = Q4
    Q5 = SD.get('Q5')
    if Q5 is None:
        Q5 = plpy.prepare(
            "SELECT min(ps.ps_suppkey) AS \"new supp\""
            "  FROM partsupp AS ps"
            " WHERE ps.ps_supplycost = $1"
            "   AND ps.ps_partkey    = ($2 :: lineitem).l_partkey",
            ["float", "lineitem"]
        )
        SD['Q5'] = Q5

    # actual logic starts here...
    if (_order := Q0.execute([orderkey])):
        order = _order[0]["order"]
    else:
        return None

    items = Q1.execute([orderkey])[0]["#items"]

    total_supplycost = 0.0
    new_supplycost   = 0.0
    new_suppliers    = []

    for item in range(1, items + 1):
        lineitem       = Q2.execute([orderkey, item])[0]["lineitem"]
        partsupp       = Q3.execute([lineitem])[0]["partsupp"]
        min_supplycost = Q4.execute([lineitem])[0]["min cost"]
        new_supplier   = Q5.execute([min_supplycost, lineitem])[0]["new supp"]

        if new_supplier != partsupp["ps_suppkey"]:
            new_suppliers.append({
                "part": lineitem["l_partkey"],
                "old":  partsupp["ps_suppkey"],
                "new":  new_supplier
            })

        total_supplycost += float(partsupp["ps_supplycost"] *       lineitem["l_quantity"])
        new_supplycost   +=       min_supplycost            * float(lineitem["l_quantity"])

    return {
        "savings": (1 - new_supplycost / total_supplycost) * 100.0,
        "supplierchanges": new_suppliers,
    }
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION savings_plsql(orderkey int4) RETURNS savings AS $$
  DECLARE
    "order"          orders;
    items            int;
    lineitem         lineitem;
    partsupp         partsupp;
    min_supplycost   float8;
    new_supplier     int;
    new_suppliers    supplierchange[];
    total_supplycost float8;
    new_supplycost   float8;
  BEGIN
    "order" := (SELECT o
                FROM   orders AS o
                WHERE  o.o_orderkey = orderkey);
    IF "order" IS NULL THEN
      RETURN NULL;
    END IF;

    -- # of lineitems (= parts) in order
    items := (SELECT COUNT(*)
              FROM   lineitem AS l
              WHERE  l.l_orderkey = orderkey);

    total_supplycost := 0.0;
    new_supplycost   := 0.0;
    new_suppliers    := array[] :: supplierchange[];

    -- iterate over all lineitems in order
    FOR item IN 1..items LOOP
      -- pick current lineitem in order
      lineitem := (SELECT l
                   FROM   lineitem AS l
                   WHERE  l.l_orderkey = orderkey AND l.l_linenumber = item);
      -- find current supplier for lineitem's part
      partsupp := (SELECT ps
                   FROM   partsupp AS ps
                   WHERE  lineitem.l_partkey = ps.ps_partkey AND lineitem.l_suppkey = ps.ps_suppkey);

      -- find minimum supplycost (for ANY supplier that has sufficient stock) for the lineitem's part
      min_supplycost := (SELECT MIN(ps.ps_supplycost) :: float8
                         FROM   partsupp AS ps
                         WHERE  ps.ps_partkey = lineitem.l_partkey
                         AND    ps.ps_availqty >= lineitem.l_quantity);

      -- new supplier with minimum supplycost
      new_supplier := (SELECT MIN(ps.ps_suppkey)
                       FROM   partsupp AS ps
                       WHERE  ps.ps_supplycost = min_supplycost
                       AND    ps.ps_partkey = lineitem.l_partkey);

      -- record whether supplier has changed (part, old, new)
      IF new_supplier <> partsupp.ps_suppkey THEN
        new_suppliers := (lineitem.l_partkey, partsupp.ps_suppkey, new_supplier) :: supplierchange || new_suppliers;
      END IF;

      -- total supplycost of original and new supplier
      total_supplycost := total_supplycost + partsupp.ps_supplycost * lineitem.l_quantity;
      new_supplycost   := new_supplycost   + min_supplycost         * lineitem.l_quantity;
    END LOOP;

    RETURN ((1.0 - new_supplycost / total_supplycost) * 100.0, new_suppliers) :: savings;
  END;
$$ LANGUAGE plpgsql;