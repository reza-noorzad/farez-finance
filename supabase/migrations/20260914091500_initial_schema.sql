


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."bootstrap_finance_family"() RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  current_user_id uuid;
  existing_family_id uuid;
  new_family_id uuid;
begin
  current_user_id := auth.uid();

  if current_user_id is null then
    raise exception 'Not authenticated';
  end if;

  -- Ø¬Ù„ÙˆÚ¯ÛŒØ±ÛŒ Ø§Ø² Ø§Ø¬Ø±Ø§ÛŒ Ù‡Ù…Ø²Ù…Ø§Ù† Ø¨Ø±Ø§ÛŒ ÛŒÚ© user
  perform pg_advisory_xact_lock(hashtext(current_user_id::text));

  select fm.family_id
  into existing_family_id
  from public.family_members fm
  where fm.user_id = current_user_id
  limit 1;

  if existing_family_id is null then
    insert into public.families (
      name,
      created_by
    )
    values (
      'Demo Family',
      current_user_id
    )
    returning id into new_family_id;

    insert into public.family_members (
      family_id,
      user_id,
      role
    )
    values (
      new_family_id,
      current_user_id,
      'owner'
    );

    existing_family_id := new_family_id;
  end if;

  insert into public.accounts (
    family_id,
    name,
    kind,
    balance,
    icon_name,
    color_value,
    is_active,
    show_in_dashboard,
    created_by
  )
  values (
    existing_family_id,
    'Bank Account',
    'account',
    0,
    'account_balance',
    4280391411,
    true,
    true,
    current_user_id
  )
  on conflict (family_id, kind, name) do nothing;

  insert into public.accounts (
    family_id,
    name,
    kind,
    balance,
    icon_name,
    color_value,
    is_active,
    show_in_dashboard,
    created_by
  )
  values (
    existing_family_id,
    'Cash Wallet',
    'account',
    0,
    'payments',
    4283215696,
    true,
    true,
    current_user_id
  )
  on conflict (family_id, kind, name) do nothing;

  return existing_family_id;
end;
$$;


ALTER FUNCTION "public"."bootstrap_finance_family"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_finance_family_member"("target_family_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.family_members fm
    where fm.family_id = target_family_id
      and fm.user_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_finance_family_member"("target_family_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."accounts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "kind" "text" NOT NULL,
    "balance" numeric DEFAULT 0 NOT NULL,
    "icon_name" "text" DEFAULT 'account_balance'::"text" NOT NULL,
    "color_value" bigint DEFAULT '4280391411'::bigint NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "show_in_dashboard" boolean DEFAULT true NOT NULL,
    "target_amount" numeric,
    "start_date" "date",
    "target_date" "date",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "accounts_kind_check" CHECK (("kind" = ANY (ARRAY['account'::"text", 'fund'::"text"])))
);


ALTER TABLE "public"."accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."app_settings" (
    "user_id" "uuid" NOT NULL,
    "language" "text" DEFAULT 'german'::"text" NOT NULL,
    "currency_code" "text" DEFAULT 'EUR'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."app_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" DEFAULT 'transaction'::"text" NOT NULL,
    "direction" "text" DEFAULT 'both'::"text" NOT NULL,
    "parent_id" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "show_in_dashboard" boolean DEFAULT true NOT NULL,
    "icon_name" "text" DEFAULT 'other'::"text" NOT NULL,
    "color_value" bigint DEFAULT '4280391411'::bigint NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."debt_payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "debt_id" "uuid" NOT NULL,
    "transaction_id" "uuid",
    "amount" numeric NOT NULL,
    "payment_date" "date" NOT NULL,
    "account_id" "uuid",
    "note" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "affects_balance" boolean DEFAULT true NOT NULL,
    CONSTRAINT "debt_payments_amount_check" CHECK (("amount" >= (0)::numeric))
);


ALTER TABLE "public"."debt_payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."debts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "transaction_id" "uuid",
    "person_name" "text" NOT NULL,
    "kind" "text" NOT NULL,
    "original_amount" numeric NOT NULL,
    "debt_date" "date" NOT NULL,
    "due_date" "date",
    "account_id" "uuid",
    "note" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_opening_balance" boolean DEFAULT false NOT NULL,
    CONSTRAINT "debts_kind_check" CHECK (("kind" = ANY (ARRAY['moneyLent'::"text", 'moneyBorrowed'::"text"]))),
    CONSTRAINT "debts_original_amount_check" CHECK (("original_amount" >= (0)::numeric))
);


ALTER TABLE "public"."debts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expense_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "expense_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "original_name" "text",
    "monthly_name" "text",
    "category" "text" DEFAULT 'Sonstiges'::"text" NOT NULL,
    "quantity" numeric DEFAULT 1 NOT NULL,
    "unit" "text" DEFAULT 'StÃ¼ck'::"text" NOT NULL,
    "total_price" numeric DEFAULT 0 NOT NULL,
    "item_date" "date" NOT NULL,
    "store_name" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "weight_grams" numeric(12,2),
    "volume_ml" numeric(12,2),
    "count_units" numeric(12,2),
    "is_measurement_important" boolean DEFAULT false NOT NULL,
    "needs_review" boolean DEFAULT false NOT NULL,
    "review_reason" "text",
    "measurement_status" "text" DEFAULT 'unknown'::"text" NOT NULL
);


ALTER TABLE "public"."expense_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expenses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "transaction_id" "uuid",
    "title" "text" NOT NULL,
    "category_id" "uuid",
    "amount" numeric NOT NULL,
    "transaction_date" "date" NOT NULL,
    "store_name" "text",
    "note" "text",
    "is_recurring" boolean DEFAULT false NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "expenses_amount_check" CHECK (("amount" >= (0)::numeric))
);


ALTER TABLE "public"."expenses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."families" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."families" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."family_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'member'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."family_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."financial_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "amount" numeric NOT NULL,
    "transaction_date" "date" NOT NULL,
    "title" "text" NOT NULL,
    "from_account_id" "uuid",
    "to_account_id" "uuid",
    "category_id" "uuid",
    "travel_plan_id" "uuid",
    "debt_id" "uuid",
    "note" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "affects_balance" boolean DEFAULT true NOT NULL,
    CONSTRAINT "financial_transactions_amount_check" CHECK (("amount" >= (0)::numeric))
);


ALTER TABLE "public"."financial_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."incomes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "transaction_id" "uuid",
    "title" "text" NOT NULL,
    "category_id" "uuid",
    "amount" numeric NOT NULL,
    "transaction_date" "date" NOT NULL,
    "note" "text",
    "is_recurring" boolean DEFAULT false NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "incomes_amount_check" CHECK (("amount" >= (0)::numeric))
);


ALTER TABLE "public"."incomes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."monthly_budgets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "category_id" "uuid" NOT NULL,
    "month_date" "date" NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    CONSTRAINT "monthly_budgets_amount_check" CHECK (("amount" > (0)::numeric))
);


ALTER TABLE "public"."monthly_budgets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "user_id" "uuid" NOT NULL,
    "email" "text" DEFAULT ''::"text" NOT NULL,
    "display_name" "text" DEFAULT 'Benutzer'::"text" NOT NULL,
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."saving_goal_reservations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "fund_id" "uuid" NOT NULL,
    "source_account_id" "uuid",
    "amount" numeric(12,2) NOT NULL,
    "reservation_date" "date" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    CONSTRAINT "saving_goal_reservations_amount_check" CHECK (("amount" <> (0)::numeric))
);


ALTER TABLE "public"."saving_goal_reservations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."travel_contributions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "travel_plan_id" "uuid" NOT NULL,
    "transaction_id" "uuid",
    "amount" numeric(12,2) NOT NULL,
    "contribution_date" "date" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    "source_account_id" "uuid",
    CONSTRAINT "travel_contributions_amount_check" CHECK (("amount" <> (0)::numeric))
);


ALTER TABLE "public"."travel_contributions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."travel_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "family_id" "uuid" NOT NULL,
    "destination" "text" NOT NULL,
    "target_budget" numeric(12,2) NOT NULL,
    "travel_date" "date" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    CONSTRAINT "travel_plans_target_budget_check" CHECK (("target_budget" > (0)::numeric))
);


ALTER TABLE "public"."travel_plans" OWNER TO "postgres";


ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."debt_payments"
    ADD CONSTRAINT "debt_payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."debts"
    ADD CONSTRAINT "debts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expense_items"
    ADD CONSTRAINT "expense_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."families"
    ADD CONSTRAINT "families_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."family_members"
    ADD CONSTRAINT "family_members_family_id_user_id_key" UNIQUE ("family_id", "user_id");



ALTER TABLE ONLY "public"."family_members"
    ADD CONSTRAINT "family_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."financial_transactions"
    ADD CONSTRAINT "financial_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."incomes"
    ADD CONSTRAINT "incomes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."monthly_budgets"
    ADD CONSTRAINT "monthly_budgets_family_id_category_id_month_date_key" UNIQUE ("family_id", "category_id", "month_date");



ALTER TABLE ONLY "public"."monthly_budgets"
    ADD CONSTRAINT "monthly_budgets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."saving_goal_reservations"
    ADD CONSTRAINT "saving_goal_reservations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."travel_contributions"
    ADD CONSTRAINT "travel_contributions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."travel_plans"
    ADD CONSTRAINT "travel_plans_pkey" PRIMARY KEY ("id");



CREATE UNIQUE INDEX "accounts_unique_default_names_per_family" ON "public"."accounts" USING "btree" ("family_id", "kind", "name");



CREATE UNIQUE INDEX "family_members_one_family_per_user" ON "public"."family_members" USING "btree" ("user_id");



ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accounts"
    ADD CONSTRAINT "accounts_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."app_settings"
    ADD CONSTRAINT "app_settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."debt_payments"
    ADD CONSTRAINT "debt_payments_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."accounts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."debt_payments"
    ADD CONSTRAINT "debt_payments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."debt_payments"
    ADD CONSTRAINT "debt_payments_debt_id_fkey" FOREIGN KEY ("debt_id") REFERENCES "public"."debts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."debt_payments"
    ADD CONSTRAINT "debt_payments_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."debt_payments"
    ADD CONSTRAINT "debt_payments_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."financial_transactions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."debts"
    ADD CONSTRAINT "debts_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."accounts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."debts"
    ADD CONSTRAINT "debts_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."debts"
    ADD CONSTRAINT "debts_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."debts"
    ADD CONSTRAINT "debts_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."financial_transactions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_items"
    ADD CONSTRAINT "expense_items_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_items"
    ADD CONSTRAINT "expense_items_expense_id_fkey" FOREIGN KEY ("expense_id") REFERENCES "public"."expenses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_items"
    ADD CONSTRAINT "expense_items_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."financial_transactions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."families"
    ADD CONSTRAINT "families_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."family_members"
    ADD CONSTRAINT "family_members_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."family_members"
    ADD CONSTRAINT "family_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."financial_transactions"
    ADD CONSTRAINT "financial_transactions_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."financial_transactions"
    ADD CONSTRAINT "financial_transactions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."financial_transactions"
    ADD CONSTRAINT "financial_transactions_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."financial_transactions"
    ADD CONSTRAINT "financial_transactions_from_account_id_fkey" FOREIGN KEY ("from_account_id") REFERENCES "public"."accounts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."financial_transactions"
    ADD CONSTRAINT "financial_transactions_to_account_id_fkey" FOREIGN KEY ("to_account_id") REFERENCES "public"."accounts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."incomes"
    ADD CONSTRAINT "incomes_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."incomes"
    ADD CONSTRAINT "incomes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."incomes"
    ADD CONSTRAINT "incomes_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."incomes"
    ADD CONSTRAINT "incomes_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."financial_transactions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."monthly_budgets"
    ADD CONSTRAINT "monthly_budgets_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."monthly_budgets"
    ADD CONSTRAINT "monthly_budgets_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."monthly_budgets"
    ADD CONSTRAINT "monthly_budgets_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."saving_goal_reservations"
    ADD CONSTRAINT "saving_goal_reservations_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."saving_goal_reservations"
    ADD CONSTRAINT "saving_goal_reservations_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."saving_goal_reservations"
    ADD CONSTRAINT "saving_goal_reservations_fund_id_fkey" FOREIGN KEY ("fund_id") REFERENCES "public"."accounts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."saving_goal_reservations"
    ADD CONSTRAINT "saving_goal_reservations_source_account_id_fkey" FOREIGN KEY ("source_account_id") REFERENCES "public"."accounts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."travel_contributions"
    ADD CONSTRAINT "travel_contributions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."travel_contributions"
    ADD CONSTRAINT "travel_contributions_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."travel_contributions"
    ADD CONSTRAINT "travel_contributions_source_account_id_fkey" FOREIGN KEY ("source_account_id") REFERENCES "public"."accounts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."travel_contributions"
    ADD CONSTRAINT "travel_contributions_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "public"."financial_transactions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."travel_contributions"
    ADD CONSTRAINT "travel_contributions_travel_plan_id_fkey" FOREIGN KEY ("travel_plan_id") REFERENCES "public"."travel_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."travel_plans"
    ADD CONSTRAINT "travel_plans_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."travel_plans"
    ADD CONSTRAINT "travel_plans_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "public"."families"("id") ON DELETE CASCADE;



CREATE POLICY "Profiles insert own" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Profiles select own" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Profiles update own" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."accounts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "accounts_family_access" ON "public"."accounts" TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ((("created_by" = "auth"."uid"()) AND "public"."is_finance_family_member"("family_id")));



ALTER TABLE "public"."app_settings" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "app_settings_delete" ON "public"."app_settings" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "app_settings_insert" ON "public"."app_settings" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "app_settings_select" ON "public"."app_settings" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "app_settings_update" ON "public"."app_settings" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categories_family_access" ON "public"."categories" TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ((("created_by" = "auth"."uid"()) AND "public"."is_finance_family_member"("family_id")));



ALTER TABLE "public"."debt_payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "debt_payments_family_access" ON "public"."debt_payments" TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ((("created_by" = "auth"."uid"()) AND "public"."is_finance_family_member"("family_id")));



ALTER TABLE "public"."debts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "debts_family_access" ON "public"."debts" TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ((("created_by" = "auth"."uid"()) AND "public"."is_finance_family_member"("family_id")));



ALTER TABLE "public"."expense_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "expense_items_family_access" ON "public"."expense_items" TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ((("created_by" = "auth"."uid"()) AND "public"."is_finance_family_member"("family_id")));



ALTER TABLE "public"."expenses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "expenses_family_access" ON "public"."expenses" TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ((("created_by" = "auth"."uid"()) AND "public"."is_finance_family_member"("family_id")));



ALTER TABLE "public"."families" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "families_delete_creator" ON "public"."families" FOR DELETE TO "authenticated" USING (("created_by" = "auth"."uid"()));



CREATE POLICY "families_insert_own" ON "public"."families" FOR INSERT TO "authenticated" WITH CHECK (("created_by" = "auth"."uid"()));



CREATE POLICY "families_select_member" ON "public"."families" FOR SELECT TO "authenticated" USING ((("created_by" = "auth"."uid"()) OR "public"."is_finance_family_member"("id")));



CREATE POLICY "families_update_creator" ON "public"."families" FOR UPDATE TO "authenticated" USING (("created_by" = "auth"."uid"())) WITH CHECK (("created_by" = "auth"."uid"()));



ALTER TABLE "public"."family_members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "family_members_delete_member" ON "public"."family_members" FOR DELETE TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."families" "f"
  WHERE (("f"."id" = "family_members"."family_id") AND ("f"."created_by" = "auth"."uid"()))))));



CREATE POLICY "family_members_insert_self_or_creator" ON "public"."family_members" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."families" "f"
  WHERE (("f"."id" = "family_members"."family_id") AND ("f"."created_by" = "auth"."uid"()))))));



CREATE POLICY "family_members_select_member" ON "public"."family_members" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) OR "public"."is_finance_family_member"("family_id")));



CREATE POLICY "family_members_update_member" ON "public"."family_members" FOR UPDATE TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ("public"."is_finance_family_member"("family_id"));



ALTER TABLE "public"."financial_transactions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "financial_transactions_family_access" ON "public"."financial_transactions" TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ((("created_by" = "auth"."uid"()) AND "public"."is_finance_family_member"("family_id")));



ALTER TABLE "public"."incomes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "incomes_family_access" ON "public"."incomes" TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ((("created_by" = "auth"."uid"()) AND "public"."is_finance_family_member"("family_id")));



ALTER TABLE "public"."monthly_budgets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "monthly_budgets_delete" ON "public"."monthly_budgets" FOR DELETE TO "authenticated" USING ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "monthly_budgets_insert" ON "public"."monthly_budgets" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "monthly_budgets_select" ON "public"."monthly_budgets" FOR SELECT TO "authenticated" USING ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "monthly_budgets_update" ON "public"."monthly_budgets" FOR UPDATE TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ("public"."is_finance_family_member"("family_id"));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_delete_own" ON "public"."profiles" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "profiles_insert_own" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "profiles_select_own" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."saving_goal_reservations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "saving_goal_reservations_delete" ON "public"."saving_goal_reservations" FOR DELETE TO "authenticated" USING ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "saving_goal_reservations_insert" ON "public"."saving_goal_reservations" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "saving_goal_reservations_select" ON "public"."saving_goal_reservations" FOR SELECT TO "authenticated" USING ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "saving_goal_reservations_update" ON "public"."saving_goal_reservations" FOR UPDATE TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ("public"."is_finance_family_member"("family_id"));



ALTER TABLE "public"."travel_contributions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "travel_contributions_delete" ON "public"."travel_contributions" FOR DELETE TO "authenticated" USING ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "travel_contributions_insert" ON "public"."travel_contributions" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "travel_contributions_select" ON "public"."travel_contributions" FOR SELECT TO "authenticated" USING ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "travel_contributions_update" ON "public"."travel_contributions" FOR UPDATE TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ("public"."is_finance_family_member"("family_id"));



ALTER TABLE "public"."travel_plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "travel_plans_delete" ON "public"."travel_plans" FOR DELETE TO "authenticated" USING ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "travel_plans_insert" ON "public"."travel_plans" FOR INSERT TO "authenticated" WITH CHECK ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "travel_plans_select" ON "public"."travel_plans" FOR SELECT TO "authenticated" USING ("public"."is_finance_family_member"("family_id"));



CREATE POLICY "travel_plans_update" ON "public"."travel_plans" FOR UPDATE TO "authenticated" USING ("public"."is_finance_family_member"("family_id")) WITH CHECK ("public"."is_finance_family_member"("family_id"));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."bootstrap_finance_family"() TO "authenticated";



GRANT ALL ON FUNCTION "public"."is_finance_family_member"("target_family_id" "uuid") TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."accounts" TO "anon";
GRANT ALL ON TABLE "public"."accounts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."accounts" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."app_settings" TO "anon";
GRANT ALL ON TABLE "public"."app_settings" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."app_settings" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."categories" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."debt_payments" TO "anon";
GRANT ALL ON TABLE "public"."debt_payments" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."debt_payments" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."debts" TO "anon";
GRANT ALL ON TABLE "public"."debts" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."debts" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."expense_items" TO "anon";
GRANT ALL ON TABLE "public"."expense_items" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."expense_items" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."expenses" TO "anon";
GRANT ALL ON TABLE "public"."expenses" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."expenses" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."families" TO "anon";
GRANT ALL ON TABLE "public"."families" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."families" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."family_members" TO "anon";
GRANT ALL ON TABLE "public"."family_members" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."family_members" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."financial_transactions" TO "anon";
GRANT ALL ON TABLE "public"."financial_transactions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."financial_transactions" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."incomes" TO "anon";
GRANT ALL ON TABLE "public"."incomes" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."incomes" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."monthly_budgets" TO "anon";
GRANT ALL ON TABLE "public"."monthly_budgets" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."monthly_budgets" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."saving_goal_reservations" TO "anon";
GRANT ALL ON TABLE "public"."saving_goal_reservations" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."saving_goal_reservations" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."travel_contributions" TO "anon";
GRANT ALL ON TABLE "public"."travel_contributions" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."travel_contributions" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."travel_plans" TO "anon";
GRANT ALL ON TABLE "public"."travel_plans" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."travel_plans" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";








