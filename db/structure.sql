SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: assign_business_id_from_guc(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_business_id_from_guc() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.business_id := current_setting('app.business_id')::uuid;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    action character varying NOT NULL,
    resource character varying NOT NULL,
    resource_id character varying,
    actor_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.audit_logs FORCE ROW LEVEL SECURITY;


--
-- Name: businesses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.businesses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    currency character varying DEFAULT 'BRL'::character varying NOT NULL,
    timezone character varying DEFAULT 'America/Sao_Paulo'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    menu_version integer DEFAULT 0 NOT NULL,
    delivery_fee numeric(12,2),
    CONSTRAINT businesses_delivery_fee_non_negative CHECK (((delivery_fee IS NULL) OR (delivery_fee >= (0)::numeric)))
);


--
-- Name: cash_movements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cash_movements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    cash_register_id uuid NOT NULL,
    order_id uuid,
    payment_id uuid,
    created_by_id uuid,
    movement_type character varying NOT NULL,
    category character varying NOT NULL,
    amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    reason character varying NOT NULL,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT cash_movements_amount_non_negative CHECK ((amount >= (0)::numeric)),
    CONSTRAINT cash_movements_type_is_valid CHECK (((movement_type)::text = ANY (ARRAY[('income'::character varying)::text, ('expense'::character varying)::text])))
);

ALTER TABLE ONLY public.cash_movements FORCE ROW LEVEL SECURITY;


--
-- Name: cash_registers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cash_registers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    user_id uuid NOT NULL,
    status character varying DEFAULT 'open'::character varying NOT NULL,
    opened_at timestamp(6) without time zone NOT NULL,
    closed_at timestamp(6) without time zone,
    opening_amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    expected_closing_amount numeric(12,2),
    actual_closing_amount numeric(12,2),
    drift numeric(12,2),
    reconciled boolean,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT cash_registers_opening_non_negative CHECK ((opening_amount >= (0)::numeric))
);

ALTER TABLE ONLY public.cash_registers FORCE ROW LEVEL SECURITY;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    name character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.categories FORCE ROW LEVEL SECURITY;


--
-- Name: consent_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consent_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    user_id uuid,
    data_subject_email character varying,
    consent_type character varying NOT NULL,
    consent_version character varying NOT NULL,
    consent_text_hash character varying NOT NULL,
    granted boolean DEFAULT true NOT NULL,
    ip_address character varying,
    user_agent character varying,
    withdrawn_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.consent_records FORCE ROW LEVEL SECURITY;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    name character varying NOT NULL,
    phone character varying,
    whatsapp character varying,
    birthday date,
    notes text,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.customers FORCE ROW LEVEL SECURITY;


--
-- Name: data_subject_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_subject_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    user_id uuid,
    data_subject_email character varying NOT NULL,
    request_type character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    description text,
    response_notes text,
    deadline_at timestamp(6) without time zone NOT NULL,
    completed_at timestamp(6) without time zone,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.data_subject_requests FORCE ROW LEVEL SECURITY;


--
-- Name: deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deliveries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    order_id uuid NOT NULL,
    courier_name character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT deliveries_status_is_valid CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('out_for_delivery'::character varying)::text, ('delivered'::character varying)::text])))
);

ALTER TABLE ONLY public.deliveries FORCE ROW LEVEL SECURITY;


--
-- Name: delivery_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_addresses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    order_id uuid NOT NULL,
    street character varying NOT NULL,
    number character varying,
    complement character varying,
    neighborhood character varying,
    city character varying NOT NULL,
    state character varying NOT NULL,
    zip character varying,
    reference character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.delivery_addresses FORCE ROW LEVEL SECURITY;


--
-- Name: integration_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    provider_key character varying NOT NULL,
    credentials jsonb,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.integration_settings FORCE ROW LEVEL SECURITY;


--
-- Name: order_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    order_id uuid NOT NULL,
    user_id uuid,
    event character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.order_events FORCE ROW LEVEL SECURITY;


--
-- Name: order_item_addons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_item_addons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    order_item_id uuid NOT NULL,
    product_addon_id uuid,
    name character varying NOT NULL,
    price numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT order_item_addons_price_non_negative CHECK ((price >= (0)::numeric))
);

ALTER TABLE ONLY public.order_item_addons FORCE ROW LEVEL SECURITY;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    order_id uuid NOT NULL,
    product_id uuid,
    product_variant_id uuid,
    product_name character varying NOT NULL,
    variant_name character varying,
    unit_price numeric(12,2) DEFAULT 0.0 NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    line_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT order_items_line_total_non_negative CHECK ((line_total >= (0)::numeric)),
    CONSTRAINT order_items_quantity_positive CHECK ((quantity > 0)),
    CONSTRAINT order_items_unit_price_non_negative CHECK ((unit_price >= (0)::numeric))
);

ALTER TABLE ONLY public.order_items FORCE ROW LEVEL SECURITY;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    user_id uuid,
    customer_id uuid,
    order_type character varying DEFAULT 'local'::character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    kitchen_status character varying DEFAULT 'pending'::character varying NOT NULL,
    payment_status character varying DEFAULT 'pending'::character varying NOT NULL,
    subtotal numeric(12,2) DEFAULT 0.0 NOT NULL,
    tax numeric(12,2) DEFAULT 0.0 NOT NULL,
    total numeric(12,2) DEFAULT 0.0 NOT NULL,
    notes text,
    lock_version integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    started_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    delivery_fee numeric(12,2) DEFAULT 0.0 NOT NULL,
    number bigint NOT NULL,
    CONSTRAINT orders_delivery_fee_non_negative CHECK ((delivery_fee >= (0)::numeric)),
    CONSTRAINT orders_subtotal_non_negative CHECK ((subtotal >= (0)::numeric)),
    CONSTRAINT orders_tax_non_negative CHECK ((tax >= (0)::numeric)),
    CONSTRAINT orders_total_non_negative CHECK ((total >= (0)::numeric))
);

ALTER TABLE ONLY public.orders FORCE ROW LEVEL SECURITY;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    order_id uuid NOT NULL,
    method character varying NOT NULL,
    amount numeric(12,2) DEFAULT 0.0 NOT NULL,
    status character varying DEFAULT 'succeeded'::character varying NOT NULL,
    gateway_reference character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    cash_register_id uuid,
    CONSTRAINT payments_amount_non_negative CHECK ((amount >= (0)::numeric))
);

ALTER TABLE ONLY public.payments FORCE ROW LEVEL SECURITY;


--
-- Name: privacy_incidents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.privacy_incidents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    title character varying NOT NULL,
    description text NOT NULL,
    severity character varying DEFAULT 'low'::character varying NOT NULL,
    status character varying DEFAULT 'detected'::character varying NOT NULL,
    affected_data_categories text[] DEFAULT '{}'::text[],
    affected_subjects_count integer DEFAULT 0,
    anpd_notified_at timestamp(6) without time zone,
    anpd_notification_deadline timestamp(6) without time zone,
    subjects_notified_at timestamp(6) without time zone,
    remediation_notes text,
    detected_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.privacy_incidents FORCE ROW LEVEL SECURITY;


--
-- Name: product_addon_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_addon_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    product_id uuid NOT NULL,
    name character varying NOT NULL,
    multiple boolean DEFAULT true NOT NULL,
    min_select integer DEFAULT 0 NOT NULL,
    max_select integer,
    "position" integer DEFAULT 0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.product_addon_groups FORCE ROW LEVEL SECURITY;


--
-- Name: product_addons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_addons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    product_addon_group_id uuid NOT NULL,
    name character varying NOT NULL,
    price numeric(12,2) DEFAULT 0.0 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT product_addons_price_non_negative CHECK ((price >= (0)::numeric))
);

ALTER TABLE ONLY public.product_addons FORCE ROW LEVEL SECURITY;


--
-- Name: product_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_variants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    product_id uuid NOT NULL,
    name character varying NOT NULL,
    price numeric(12,2),
    stock integer,
    active boolean DEFAULT true NOT NULL,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT product_variants_price_non_negative CHECK (((price IS NULL) OR (price >= (0)::numeric)))
);

ALTER TABLE ONLY public.product_variants FORCE ROW LEVEL SECURITY;


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    category_id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    price numeric(12,2) DEFAULT 0.0 NOT NULL,
    status character varying DEFAULT 'available'::character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    discarded_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT products_price_non_negative CHECK ((price >= (0)::numeric))
);

ALTER TABLE ONLY public.products FORCE ROW LEVEL SECURITY;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    user_id uuid NOT NULL,
    scope character varying NOT NULL,
    name character varying NOT NULL,
    token_digest character varying NOT NULL,
    expires_at timestamp(6) without time zone,
    last_used_at timestamp(6) without time zone,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    business_id uuid NOT NULL,
    name character varying NOT NULL,
    email character varying NOT NULL,
    role character varying DEFAULT 'owner'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    failed_attempts integer DEFAULT 0 NOT NULL,
    unlock_token character varying,
    locked_at timestamp(6) without time zone,
    active boolean DEFAULT true NOT NULL,
    force_password_change boolean DEFAULT false NOT NULL,
    CONSTRAINT users_role_is_valid CHECK (((role)::text = ANY (ARRAY[('owner'::character varying)::text, ('admin'::character varying)::text, ('cashier'::character varying)::text, ('kitchen'::character varying)::text])))
);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: businesses businesses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.businesses
    ADD CONSTRAINT businesses_pkey PRIMARY KEY (id);


--
-- Name: cash_movements cash_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movements
    ADD CONSTRAINT cash_movements_pkey PRIMARY KEY (id);


--
-- Name: cash_registers cash_registers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_registers
    ADD CONSTRAINT cash_registers_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: consent_records consent_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent_records
    ADD CONSTRAINT consent_records_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: data_subject_requests data_subject_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_subject_requests
    ADD CONSTRAINT data_subject_requests_pkey PRIMARY KEY (id);


--
-- Name: deliveries deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkey PRIMARY KEY (id);


--
-- Name: delivery_addresses delivery_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_addresses
    ADD CONSTRAINT delivery_addresses_pkey PRIMARY KEY (id);


--
-- Name: integration_settings integration_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_settings
    ADD CONSTRAINT integration_settings_pkey PRIMARY KEY (id);


--
-- Name: order_events order_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_events
    ADD CONSTRAINT order_events_pkey PRIMARY KEY (id);


--
-- Name: order_item_addons order_item_addons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_item_addons
    ADD CONSTRAINT order_item_addons_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: privacy_incidents privacy_incidents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_incidents
    ADD CONSTRAINT privacy_incidents_pkey PRIMARY KEY (id);


--
-- Name: product_addon_groups product_addon_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_addon_groups
    ADD CONSTRAINT product_addon_groups_pkey PRIMARY KEY (id);


--
-- Name: product_addons product_addons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_addons
    ADD CONSTRAINT product_addons_pkey PRIMARY KEY (id);


--
-- Name: product_variants product_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT product_variants_pkey PRIMARY KEY (id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tokens tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT tokens_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_consent_records_on_biz_email_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_consent_records_on_biz_email_type ON public.consent_records USING btree (business_id, data_subject_email, consent_type);


--
-- Name: idx_dsr_on_deadline_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dsr_on_deadline_pending ON public.data_subject_requests USING btree (deadline_at) WHERE ((status)::text = 'pending'::text);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_audit_logs_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_logs_on_action ON public.audit_logs USING btree (action);


--
-- Name: index_audit_logs_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_logs_on_business_id ON public.audit_logs USING btree (business_id);


--
-- Name: index_audit_logs_on_business_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_logs_on_business_id_and_created_at ON public.audit_logs USING btree (business_id, created_at);


--
-- Name: index_cash_movements_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_movements_on_business_id ON public.cash_movements USING btree (business_id);


--
-- Name: index_cash_movements_on_business_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_movements_on_business_id_and_created_at ON public.cash_movements USING btree (business_id, created_at);


--
-- Name: index_cash_movements_on_business_id_and_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_movements_on_business_id_and_order_id ON public.cash_movements USING btree (business_id, order_id);


--
-- Name: index_cash_movements_on_cash_register_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_movements_on_cash_register_id ON public.cash_movements USING btree (cash_register_id);


--
-- Name: index_cash_movements_on_cash_register_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_movements_on_cash_register_id_and_created_at ON public.cash_movements USING btree (cash_register_id, created_at);


--
-- Name: index_cash_movements_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_movements_on_created_by_id ON public.cash_movements USING btree (created_by_id);


--
-- Name: index_cash_movements_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_movements_on_order_id ON public.cash_movements USING btree (order_id);


--
-- Name: index_cash_movements_on_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_movements_on_payment_id ON public.cash_movements USING btree (payment_id);


--
-- Name: index_cash_registers_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_registers_on_business_id ON public.cash_registers USING btree (business_id);


--
-- Name: index_cash_registers_on_business_id_and_opened_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_registers_on_business_id_and_opened_at ON public.cash_registers USING btree (business_id, opened_at);


--
-- Name: index_cash_registers_on_business_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_registers_on_business_id_and_status ON public.cash_registers USING btree (business_id, status);


--
-- Name: index_cash_registers_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cash_registers_on_user_id ON public.cash_registers USING btree (user_id);


--
-- Name: index_cash_registers_one_open_shift; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_cash_registers_one_open_shift ON public.cash_registers USING btree (business_id, user_id) WHERE ((status)::text = 'open'::text);


--
-- Name: index_categories_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_business_id ON public.categories USING btree (business_id);


--
-- Name: index_categories_on_business_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_business_id_and_name ON public.categories USING btree (business_id, name);


--
-- Name: index_categories_on_business_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_business_id_and_position ON public.categories USING btree (business_id, "position");


--
-- Name: index_consent_records_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consent_records_on_business_id ON public.consent_records USING btree (business_id);


--
-- Name: index_consent_records_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_consent_records_on_user_id ON public.consent_records USING btree (user_id);


--
-- Name: index_customers_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_business_id ON public.customers USING btree (business_id);


--
-- Name: index_customers_on_business_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_business_id_and_name ON public.customers USING btree (business_id, name);


--
-- Name: index_customers_on_business_id_and_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_customers_on_business_id_and_phone ON public.customers USING btree (business_id, phone) WHERE ((phone IS NOT NULL) AND (discarded_at IS NULL));


--
-- Name: index_data_subject_requests_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_subject_requests_on_business_id ON public.data_subject_requests USING btree (business_id);


--
-- Name: index_data_subject_requests_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_subject_requests_on_user_id ON public.data_subject_requests USING btree (user_id);


--
-- Name: index_deliveries_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deliveries_on_business_id ON public.deliveries USING btree (business_id);


--
-- Name: index_deliveries_on_business_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deliveries_on_business_id_and_status ON public.deliveries USING btree (business_id, status);


--
-- Name: index_deliveries_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deliveries_on_order_id ON public.deliveries USING btree (order_id);


--
-- Name: index_delivery_addresses_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_delivery_addresses_on_business_id ON public.delivery_addresses USING btree (business_id);


--
-- Name: index_delivery_addresses_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_delivery_addresses_on_order_id ON public.delivery_addresses USING btree (order_id);


--
-- Name: index_integration_settings_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_integration_settings_on_business_id ON public.integration_settings USING btree (business_id);


--
-- Name: index_integration_settings_on_business_id_and_provider_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_integration_settings_on_business_id_and_provider_key ON public.integration_settings USING btree (business_id, provider_key);


--
-- Name: index_order_events_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_events_on_business_id ON public.order_events USING btree (business_id);


--
-- Name: index_order_events_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_events_on_order_id ON public.order_events USING btree (order_id);


--
-- Name: index_order_events_on_order_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_events_on_order_id_and_created_at ON public.order_events USING btree (order_id, created_at);


--
-- Name: index_order_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_events_on_user_id ON public.order_events USING btree (user_id);


--
-- Name: index_order_item_addons_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_item_addons_on_business_id ON public.order_item_addons USING btree (business_id);


--
-- Name: index_order_item_addons_on_order_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_item_addons_on_order_item_id ON public.order_item_addons USING btree (order_item_id);


--
-- Name: index_order_item_addons_on_product_addon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_item_addons_on_product_addon_id ON public.order_item_addons USING btree (product_addon_id);


--
-- Name: index_order_items_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_items_on_business_id ON public.order_items USING btree (business_id);


--
-- Name: index_order_items_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_items_on_order_id ON public.order_items USING btree (order_id);


--
-- Name: index_order_items_on_order_id_and_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_items_on_order_id_and_product_id ON public.order_items USING btree (order_id, product_id);


--
-- Name: index_order_items_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_items_on_product_id ON public.order_items USING btree (product_id);


--
-- Name: index_order_items_on_product_variant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_items_on_product_variant_id ON public.order_items USING btree (product_variant_id);


--
-- Name: index_orders_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_business_id ON public.orders USING btree (business_id);


--
-- Name: index_orders_on_business_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_business_id_and_created_at ON public.orders USING btree (business_id, created_at);


--
-- Name: index_orders_on_business_id_and_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_business_id_and_customer_id ON public.orders USING btree (business_id, customer_id);


--
-- Name: index_orders_on_business_id_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_orders_on_business_id_and_number ON public.orders USING btree (business_id, number);


--
-- Name: index_orders_on_business_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_business_id_and_status ON public.orders USING btree (business_id, status);


--
-- Name: index_orders_on_business_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_business_id_and_user_id ON public.orders USING btree (business_id, user_id);


--
-- Name: index_orders_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_customer_id ON public.orders USING btree (customer_id);


--
-- Name: index_orders_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_user_id ON public.orders USING btree (user_id);


--
-- Name: index_payments_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_business_id ON public.payments USING btree (business_id);


--
-- Name: index_payments_on_cash_register_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_cash_register_id ON public.payments USING btree (cash_register_id);


--
-- Name: index_payments_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_order_id ON public.payments USING btree (order_id);


--
-- Name: index_privacy_incidents_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_privacy_incidents_on_business_id ON public.privacy_incidents USING btree (business_id);


--
-- Name: index_product_addon_groups_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_addon_groups_on_business_id ON public.product_addon_groups USING btree (business_id);


--
-- Name: index_product_addon_groups_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_addon_groups_on_product_id ON public.product_addon_groups USING btree (product_id);


--
-- Name: index_product_addon_groups_on_product_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_addon_groups_on_product_id_and_position ON public.product_addon_groups USING btree (product_id, "position");


--
-- Name: index_product_addons_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_addons_on_business_id ON public.product_addons USING btree (business_id);


--
-- Name: index_product_addons_on_product_addon_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_addons_on_product_addon_group_id ON public.product_addons USING btree (product_addon_group_id);


--
-- Name: index_product_addons_on_product_addon_group_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_product_addons_on_product_addon_group_id_and_name ON public.product_addons USING btree (product_addon_group_id, name);


--
-- Name: index_product_variants_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_variants_on_business_id ON public.product_variants USING btree (business_id);


--
-- Name: index_product_variants_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_variants_on_product_id ON public.product_variants USING btree (product_id);


--
-- Name: index_product_variants_on_product_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_product_variants_on_product_id_and_name ON public.product_variants USING btree (product_id, name);


--
-- Name: index_products_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_on_business_id ON public.products USING btree (business_id);


--
-- Name: index_products_on_business_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_products_on_business_id_and_name ON public.products USING btree (business_id, name);


--
-- Name: index_products_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_on_category_id ON public.products USING btree (category_id);


--
-- Name: index_products_on_category_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_on_category_id_and_position ON public.products USING btree (category_id, "position");


--
-- Name: index_tokens_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tokens_on_business_id ON public.tokens USING btree (business_id);


--
-- Name: index_tokens_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tokens_on_token_digest ON public.tokens USING btree (token_digest);


--
-- Name: index_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tokens_on_user_id ON public.tokens USING btree (user_id);


--
-- Name: index_users_on_business_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_business_id ON public.users USING btree (business_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_unlock_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_unlock_token ON public.users USING btree (unlock_token);


--
-- Name: audit_logs audit_logs_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_logs_set_business_id BEFORE INSERT ON public.audit_logs FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: cash_movements cash_movements_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER cash_movements_set_business_id BEFORE INSERT ON public.cash_movements FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: cash_registers cash_registers_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER cash_registers_set_business_id BEFORE INSERT ON public.cash_registers FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: categories categories_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER categories_set_business_id BEFORE INSERT ON public.categories FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: consent_records consent_records_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER consent_records_set_business_id BEFORE INSERT ON public.consent_records FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: customers customers_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER customers_set_business_id BEFORE INSERT ON public.customers FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: data_subject_requests data_subject_requests_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER data_subject_requests_set_business_id BEFORE INSERT ON public.data_subject_requests FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: deliveries deliveries_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER deliveries_set_business_id BEFORE INSERT ON public.deliveries FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: delivery_addresses delivery_addresses_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER delivery_addresses_set_business_id BEFORE INSERT ON public.delivery_addresses FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: integration_settings integration_settings_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER integration_settings_set_business_id BEFORE INSERT ON public.integration_settings FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: order_events order_events_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER order_events_set_business_id BEFORE INSERT ON public.order_events FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: order_item_addons order_item_addons_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER order_item_addons_set_business_id BEFORE INSERT ON public.order_item_addons FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: order_items order_items_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER order_items_set_business_id BEFORE INSERT ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: orders orders_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER orders_set_business_id BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: payments payments_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payments_set_business_id BEFORE INSERT ON public.payments FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: privacy_incidents privacy_incidents_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER privacy_incidents_set_business_id BEFORE INSERT ON public.privacy_incidents FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: product_addon_groups product_addon_groups_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_addon_groups_set_business_id BEFORE INSERT ON public.product_addon_groups FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: product_addons product_addons_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_addons_set_business_id BEFORE INSERT ON public.product_addons FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: product_variants product_variants_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER product_variants_set_business_id BEFORE INSERT ON public.product_variants FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: products products_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER products_set_business_id BEFORE INSERT ON public.products FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


--
-- Name: orders fk_rails_105a300374; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_105a300374 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: integration_settings fk_rails_10f8876694; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_settings
    ADD CONSTRAINT fk_rails_10f8876694 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: delivery_addresses fk_rails_15246c44c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_addresses
    ADD CONSTRAINT fk_rails_15246c44c0 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: delivery_addresses fk_rails_1baa12114a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_addresses
    ADD CONSTRAINT fk_rails_1baa12114a FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: cash_movements fk_rails_1bd56f86b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movements
    ADD CONSTRAINT fk_rails_1bd56f86b5 FOREIGN KEY (cash_register_id) REFERENCES public.cash_registers(id);


--
-- Name: order_events fk_rails_21d02ca34e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_events
    ADD CONSTRAINT fk_rails_21d02ca34e FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: consent_records fk_rails_282f08b4f7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent_records
    ADD CONSTRAINT fk_rails_282f08b4f7 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: cash_movements fk_rails_3244ed8937; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movements
    ADD CONSTRAINT fk_rails_3244ed8937 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: payments fk_rails_397ed43c6d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_397ed43c6d FOREIGN KEY (cash_register_id) REFERENCES public.cash_registers(id);


--
-- Name: orders fk_rails_3dad120da9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_3dad120da9 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: deliveries fk_rails_3eba625948; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT fk_rails_3eba625948 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: product_addons fk_rails_3f312f5c47; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_addons
    ADD CONSTRAINT fk_rails_3f312f5c47 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: order_item_addons fk_rails_46bab3fae0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_item_addons
    ADD CONSTRAINT fk_rails_46bab3fae0 FOREIGN KEY (order_item_id) REFERENCES public.order_items(id);


--
-- Name: product_variants fk_rails_473ed375b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT fk_rails_473ed375b9 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: consent_records fk_rails_57c104c14a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent_records
    ADD CONSTRAINT fk_rails_57c104c14a FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: audit_logs fk_rails_5973e49273; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT fk_rails_5973e49273 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: product_addon_groups fk_rails_5a0dd53a67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_addon_groups
    ADD CONSTRAINT fk_rails_5a0dd53a67 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: order_item_addons fk_rails_638c785368; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_item_addons
    ADD CONSTRAINT fk_rails_638c785368 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: data_subject_requests fk_rails_63ad2f354d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_subject_requests
    ADD CONSTRAINT fk_rails_63ad2f354d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: products fk_rails_64b1679e02; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_64b1679e02 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: payments fk_rails_6af949464b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_6af949464b FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: cash_movements fk_rails_6d01aba9ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movements
    ADD CONSTRAINT fk_rails_6d01aba9ef FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: product_addons fk_rails_733f99f579; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_addons
    ADD CONSTRAINT fk_rails_733f99f579 FOREIGN KEY (product_addon_group_id) REFERENCES public.product_addon_groups(id);


--
-- Name: categories fk_rails_798ddcc841; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT fk_rails_798ddcc841 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: cash_registers fk_rails_7b6b1f3b1f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_registers
    ADD CONSTRAINT fk_rails_7b6b1f3b1f FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: order_items fk_rails_a64865ed76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_rails_a64865ed76 FOREIGN KEY (product_variant_id) REFERENCES public.product_variants(id);


--
-- Name: tokens fk_rails_ac8a5d0441; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT fk_rails_ac8a5d0441 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: customers fk_rails_b73113df4b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_b73113df4b FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: order_events fk_rails_b965cef937; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_events
    ADD CONSTRAINT fk_rails_b965cef937 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: order_items fk_rails_c5148c6bf8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_rails_c5148c6bf8 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: privacy_incidents fk_rails_cacac7d798; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_incidents
    ADD CONSTRAINT fk_rails_cacac7d798 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: cash_movements fk_rails_cc82f643e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movements
    ADD CONSTRAINT fk_rails_cc82f643e9 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: tokens fk_rails_ceb21ae632; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tokens
    ADD CONSTRAINT fk_rails_ceb21ae632 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: cash_registers fk_rails_d0e08f4ceb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_registers
    ADD CONSTRAINT fk_rails_d0e08f4ceb FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: order_events fk_rails_d231296bb6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_events
    ADD CONSTRAINT fk_rails_d231296bb6 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: product_addon_groups fk_rails_d4ff722d57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_addon_groups
    ADD CONSTRAINT fk_rails_d4ff722d57 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: data_subject_requests fk_rails_d83c35524b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_subject_requests
    ADD CONSTRAINT fk_rails_d83c35524b FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: product_variants fk_rails_dae52f850b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT fk_rails_dae52f850b FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: order_items fk_rails_e3cb28f071; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_rails_e3cb28f071 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: cash_movements fk_rails_f0e568e304; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cash_movements
    ADD CONSTRAINT fk_rails_f0e568e304 FOREIGN KEY (payment_id) REFERENCES public.payments(id);


--
-- Name: order_items fk_rails_f1a29ddd47; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT fk_rails_f1a29ddd47 FOREIGN KEY (product_id) REFERENCES public.products(id);


--
-- Name: order_item_addons fk_rails_f5dc39ae33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_item_addons
    ADD CONSTRAINT fk_rails_f5dc39ae33 FOREIGN KEY (product_addon_id) REFERENCES public.product_addons(id);


--
-- Name: orders fk_rails_f868b47f6a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_f868b47f6a FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: payments fk_rails_fade6fd17c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT fk_rails_fade6fd17c FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: deliveries fk_rails_fb5eb13f33; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT fk_rails_fb5eb13f33 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: products fk_rails_fb915499a4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_fb915499a4 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: users fk_rails_ffa8fa13ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_ffa8fa13ef FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: cash_movements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cash_movements ENABLE ROW LEVEL SECURITY;

--
-- Name: cash_registers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cash_registers ENABLE ROW LEVEL SECURITY;

--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: consent_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.consent_records ENABLE ROW LEVEL SECURITY;

--
-- Name: customers; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

--
-- Name: data_subject_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.data_subject_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: deliveries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

--
-- Name: delivery_addresses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.delivery_addresses ENABLE ROW LEVEL SECURITY;

--
-- Name: integration_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.integration_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: order_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.order_events ENABLE ROW LEVEL SECURITY;

--
-- Name: order_item_addons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.order_item_addons ENABLE ROW LEVEL SECURITY;

--
-- Name: order_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

--
-- Name: orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

--
-- Name: payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

--
-- Name: privacy_incidents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.privacy_incidents ENABLE ROW LEVEL SECURITY;

--
-- Name: product_addon_groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_addon_groups ENABLE ROW LEVEL SECURITY;

--
-- Name: product_addons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_addons ENABLE ROW LEVEL SECURITY;

--
-- Name: product_variants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;

--
-- Name: products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.audit_logs USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: cash_movements tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.cash_movements USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: cash_registers tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.cash_registers USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: categories tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.categories USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: consent_records tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.consent_records USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: customers tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.customers USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: data_subject_requests tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.data_subject_requests USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: deliveries tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.deliveries USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: delivery_addresses tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.delivery_addresses USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: integration_settings tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.integration_settings USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: order_events tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.order_events USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: order_item_addons tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.order_item_addons USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: order_items tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.order_items USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: orders tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.orders USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: payments tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.payments USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: privacy_incidents tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.privacy_incidents USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: product_addon_groups tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.product_addon_groups USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: product_addons tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.product_addons USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: product_variants tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.product_variants USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- Name: products tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.products USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260829090000'),
('20260826040000'),
('20260826020000'),
('20260822150000'),
('20260819201103'),
('20260809020000'),
('20260807120001'),
('20260804130004'),
('20260804130003'),
('20260804130002'),
('20260804130001'),
('20260804050000'),
('20260804040000'),
('20260804030002'),
('20260804030001'),
('20260804030000'),
('20260804020004'),
('20260804020003'),
('20260804020002'),
('20260804020001'),
('20260804020000'),
('20260804010005'),
('20260804010004'),
('20260804010003'),
('20260804010002'),
('20260804010001'),
('20260804010000'),
('20260804003452'),
('20260803231900'),
('20260803231459'),
('20260803231458'),
('20260803201000'),
('20260803200000');

