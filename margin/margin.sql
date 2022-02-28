-- ByePy - TPC-H Margins Example
-- Copyright (C) 2022  Tim Fischer
--
-- margin.sql
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

CREATE OR REPLACE FUNCTION margin_start(partkey int4) RETURNS trade
AS
$$
    WITH RECURSIVE run("rec?", 
                       "res",
                       "partkey",
                       "cheapest",
                       "margin",
                       "this_order",
                       "price",
                       "cheapest_order",
                       "profit",
                       "buy",
                       "sell") AS
    (
        (SELECT True,
                NULL :: trade,
                "partkey",
                ('+inf') :: float8,
                ('-inf') :: float8,
                (SELECT ("o"."o_orderkey", "o"."o_orderdate") :: datedorder
                 FROM lineitem AS "l", orders AS "o"
                 WHERE "l"."l_orderkey" = "o"."o_orderkey"
                 AND   "l"."l_partkey" = "partkey"
                 ORDER BY ("o"."o_orderdate") ASC
                 LIMIT 1) AS "this_order_1",
                NULL :: float8,
                NULL :: int4,
                NULL :: float8,
                NULL :: int4,
                NULL :: int4)
          UNION ALL
        (SELECT "result".*
         FROM run AS "run"("rec?",
                           "res",
                           "partkey",
                           "cheapest",
                           "margin",
                           "this_order",
                           "price",
                           "cheapest_order",
                           "profit",
                           "buy",
                           "sell"),
              LATERAL
              (SELECT "ifresult4".*
               FROM LATERAL
                    (SELECT "this_order" IS NOT NULL AS "pred2_2") AS "let3"("pred2_2"),
                    LATERAL
                    ((SELECT "ifresult8".*
                      FROM LATERAL
                           (SELECT min("l"."l_extendedprice" * (1 - "l"."l_discount") * (1 + "l"."l_tax")) :: float8
                              FROM lineitem AS "l"
                             WHERE "l"."l_partkey" = "partkey"
                               AND "l"."l_orderkey" = ("this_order" :: datedorder).orderkey) AS "let6"("price_3"),
                           LATERAL (SELECT "price_3" <= "cheapest" AS "q7_3") AS "let7"("q7_3"),
                           LATERAL
                           ((SELECT "ifresult13".*
                             FROM LATERAL
                                  (SELECT "price_3" AS "cheapest_8") AS "let9"("cheapest_8"),
                                  LATERAL
                                  (SELECT ("this_order" :: datedorder).orderkey AS "cheapest_order_7"
                                  ) AS "let10"("cheapest_order_7"),
                                  LATERAL
                                  (SELECT "price_3" - "cheapest_8" AS "profit_4"
                                  ) AS "let11"("profit_4"),
                                  LATERAL
                                  (SELECT "profit_4" >= "margin" AS "q11_4") AS "let12"("q11_4"),
                                  LATERAL
                                  ((SELECT True,
                                           NULL :: trade,
                                           "partkey",
                                           "cheapest_8",
                                           "profit_4" AS "margin_7",
                                           (SELECT ("o"."o_orderkey", "o"."o_orderdate") :: datedorder
                                              FROM lineitem AS "l", orders AS "o"
                                             WHERE "l"."l_orderkey" = "o"."o_orderkey"
                                               AND "l"."l_partkey" = "partkey"
                                               AND "o"."o_orderdate" > ("this_order" :: datedorder).orderdate
                                             ORDER BY ("o"."o_orderdate") ASC
                                             LIMIT 1) AS "this_order_6",
                                           "price_3",
                                           "cheapest_order_7",
                                           "profit_4",
                                           "cheapest_order_7" AS "buy_6",
                                           ("this_order" :: datedorder).orderkey AS "sell_6"
                                    WHERE NOT "q11_4" IS DISTINCT FROM True)
                                     UNION ALL
                                   (SELECT True,
                                           NULL :: trade,
                                           "partkey",
                                           "cheapest_8",
                                           "margin",
                                           (SELECT ("o"."o_orderkey", "o"."o_orderdate") :: datedorder
                                              FROM lineitem AS "l", orders AS "o"
                                             WHERE "l"."l_orderkey" = "o"."o_orderkey"
                                               AND "l"."l_partkey" = "partkey"
                                               AND "o"."o_orderdate" > ("this_order" :: datedorder).orderdate
                                             ORDER BY ("o"."o_orderdate") ASC
                                             LIMIT 1) AS "this_order_6",
                                           "price_3",
                                           "cheapest_order_7",
                                           "profit_4",
                                           "buy",
                                           "sell"
                                    WHERE "q11_4" IS DISTINCT FROM True)
                                  ) AS "ifresult13"
                             WHERE NOT "q7_3" IS DISTINCT FROM True)
                              UNION ALL
                            (SELECT "ifresult25".*
                             FROM LATERAL
                                  (SELECT "price_3" - "cheapest" AS "profit_4"
                                  ) AS "let23"("profit_4"),
                                  LATERAL
                                  (SELECT "profit_4" >= "margin" AS "q11_4") AS "let24"("q11_4"),
                                  LATERAL
                                  ((SELECT True,
                                           NULL :: trade,
                                           "partkey",
                                           "cheapest",
                                           "profit_4" AS "margin_7",
                                           (SELECT ("o"."o_orderkey", "o"."o_orderdate") :: datedorder
                                              FROM lineitem AS "l", orders AS "o"
                                             WHERE "l"."l_orderkey" = "o"."o_orderkey"
                                               AND "l"."l_partkey" = "partkey"
                                               AND "o"."o_orderdate" > ("this_order" :: datedorder).orderdate
                                             ORDER BY ("o"."o_orderdate") ASC
                                             LIMIT 1) AS "this_order_6",
                                           "price_3",
                                           "cheapest_order",
                                           "profit_4",
                                           "cheapest_order" AS "buy_6",
                                           ("this_order" :: datedorder).orderkey AS "sell_6"
                                    WHERE NOT "q11_4" IS DISTINCT FROM True)
                                     UNION ALL
                                   (SELECT True,
                                           NULL :: trade,
                                           "partkey",
                                           "cheapest",
                                           "margin",
                                           (SELECT ("o"."o_orderkey", "o"."o_orderdate") :: datedorder
                                              FROM lineitem AS "l", orders AS "o"
                                             WHERE "l"."l_orderkey" = "o"."o_orderkey"
                                               AND "l"."l_partkey" = "partkey"
                                               AND "o"."o_orderdate" > ("this_order" :: datedorder).orderdate
                                             ORDER BY ("o"."o_orderdate") ASC
                                             LIMIT 1) AS "this_order_6",
                                           "price_3",
                                           "cheapest_order",
                                           "profit_4",
                                           "buy",
                                           "sell"
                                    WHERE "q11_4" IS DISTINCT FROM True)
                                  ) AS "ifresult25"
                             WHERE "q7_3" IS DISTINCT FROM True)
                           ) AS "ifresult8"
                      WHERE NOT "pred2_2" IS DISTINCT FROM True)
                       UNION ALL
                     (SELECT False,
                             ("buy", "sell", "margin") :: trade AS "result",
                             "run"."partkey",
                             "run"."cheapest",
                             "run"."margin",
                             "run"."this_order",
                             "run"."price",
                             "run"."cheapest_order",
                             "run"."profit",
                             "run"."buy",
                             "run"."sell"
                      WHERE "pred2_2" IS DISTINCT FROM True)
                    ) AS "ifresult4"
              ) AS "result"
         WHERE "run"."rec?")
    )
    SELECT "run"."res" AS "res"
    FROM run AS "run"
    WHERE NOT "run"."rec?"
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION margin_plpython(partkey int4) RETURNS Trade AS $$
    # avoid duplicate plan preparation
    Q0 = SD.get('Q0')
    if Q0 is None:
        Q0 = plpy.prepare(
            "SELECT (o.o_orderkey, o.o_orderdate) :: datedorder AS order"
            "  FROM lineitem AS l, orders AS o"
            " WHERE l.l_orderkey = o.o_orderkey"
            "   AND l.l_partkey  = $1"
            " ORDER BY o.o_orderdate"
            " LIMIT 1",
            ["int4"]
        )
        SD['Q0'] = Q0
    Q1 = SD.get('Q1')
    if Q1 is None:
        Q1 = plpy.prepare(
            "SELECT MIN(l.l_extendedprice * (1 - l.l_discount) * (1 + l.l_tax)) :: float8 AS price"
            "  FROM lineitem AS l"
            " WHERE l.l_partkey  = $1"
            "   AND l.l_orderkey = ($2 :: datedorder).orderkey",
            ["int4", "datedorder"]
        )
        SD['Q1'] = Q1
    Q2 = SD.get('Q2')
    if Q2 is None:
        Q2 = plpy.prepare(
            "SELECT (o.o_orderkey, o.o_orderdate) :: datedorder AS order"
            "  FROM lineitem AS l, orders AS o"
            " WHERE l.l_orderkey = o.o_orderkey"
            "   AND l.l_partkey  = ($1)"
            "   AND o.o_orderdate > ($2 :: datedorder).orderdate"
            " ORDER BY o.o_orderdate"
            " LIMIT 1",
            ["int4", "datedorder"]
        )
        SD['Q2'] = Q2


    cheapest = float('+inf')
    margin = float('-inf')
    buy = None
    sell = None

    # ➊ first order for the given part
    _this_order = Q0.execute([partkey])
    if len(_this_order) > 0:
        this_order = _this_order[0]["order"]
    else:
        this_order = None

    # hunt for the best margin while there are more orders to consider
    while this_order is not None:
        # ➋ price of part in this order
        price = Q1.execute([partkey, this_order])[0]["price"]

        # if this is the new cheapest price, remember it
        if price <= cheapest:
            cheapest       = price
            cheapest_order = this_order["orderkey"]

        # compute current obtainable margin
        profit = price - cheapest
        if profit >= margin:
            buy    = cheapest_order
            sell   = this_order["orderkey"]
            margin = profit

        # ➌ find next order (if any) that traded the part
        _this_order = Q2.execute([partkey, this_order])
        if len(_this_order) > 0:
            this_order = _this_order[0]["order"]
        else:
            this_order = None

    return {
        "buy": buy,
        "sell": sell,
        "margin": margin
    }
$$ LANGUAGE plpython3u;

CREATE OR REPLACE FUNCTION margin_plsql(partkey int4) RETURNS Trade AS $$
  DECLARE
    this_order     datedorder;
    buy            int           := NULL;
    sell           int           := NULL;
    margin         numeric(15,2) := NULL;
    cheapest       numeric(15,2) := NULL;
    cheapest_order int;
    price          numeric(15,2);
    profit         numeric(15,2);
  BEGIN
    -- ➊ first order for the given part
    this_order := (SELECT (o.o_orderkey, o.o_orderdate) :: datedorder
                   FROM   lineitem AS l, orders AS o
                   WHERE  l.l_orderkey = o.o_orderkey
                   AND    l.l_partkey  = partkey
                   ORDER BY o.o_orderdate
                   LIMIT 1);

    -- hunt for the best margin while there are more orders to consider
    WHILE this_order IS NOT NULL LOOP
      -- ➋ price of part in this order
      price := (SELECT MIN(l.l_extendedprice * (1 - l.l_discount) * (1 + l.l_tax))
                FROM   lineitem AS l
                WHERE  l.l_orderkey = this_order.orderkey
                AND    l.l_partkey  = partkey);

      -- if this the new cheapest price, remember it
      cheapest := COALESCE(cheapest, price);
      IF price <= cheapest THEN
        cheapest       := price;
        cheapest_order := this_order.orderkey;
      END IF;
      -- compute current obtainable margin
      profit := price - cheapest;
      margin := COALESCE(margin, profit);
      IF profit >= margin THEN
        buy    := cheapest_order;
        sell   := this_order.orderkey;
        margin := profit;
      END IF;

      -- ➌ find next order (if any) that traded the part
      this_order := (SELECT (o.o_orderkey, o.o_orderdate) :: datedorder
                     FROM   lineitem AS l, orders AS o
                     WHERE  l.l_orderkey = o.o_orderkey
                     AND    l.l_partkey  = partkey
                     AND    o.o_orderdate > this_order.orderdate
                     ORDER BY o.o_orderdate
                     LIMIT 1);
    END LOOP;

    RETURN (buy, sell, margin) :: trade;
  END;
$$ LANGUAGE plpgsql;