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
    menu_version integer DEFAULT 0 NOT NULL
);


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
    CONSTRAINT users_role_is_valid CHECK (((role)::text = ANY (ARRAY[('owner'::character varying)::text, ('cashier'::character varying)::text, ('kitchen'::character varying)::text])))
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
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


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
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


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
-- Name: categories categories_set_business_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER categories_set_business_id BEFORE INSERT ON public.categories FOR EACH ROW EXECUTE FUNCTION public.assign_business_id_from_guc();


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
-- Name: product_addons fk_rails_3f312f5c47; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_addons
    ADD CONSTRAINT fk_rails_3f312f5c47 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: product_variants fk_rails_473ed375b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT fk_rails_473ed375b9 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


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
-- Name: products fk_rails_64b1679e02; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT fk_rails_64b1679e02 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


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
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: product_addon_groups fk_rails_d4ff722d57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_addon_groups
    ADD CONSTRAINT fk_rails_d4ff722d57 FOREIGN KEY (business_id) REFERENCES public.businesses(id);


--
-- Name: product_variants fk_rails_dae52f850b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_variants
    ADD CONSTRAINT fk_rails_dae52f850b FOREIGN KEY (product_id) REFERENCES public.products(id);


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
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

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
-- Name: categories tenant_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tenant_isolation ON public.categories USING ((business_id = (current_setting('app.business_id'::text))::uuid)) WITH CHECK ((business_id = (current_setting('app.business_id'::text))::uuid));


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

