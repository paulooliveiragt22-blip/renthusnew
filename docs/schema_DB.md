-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.admin_users (
  user_id uuid NOT NULL,
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  created_by uuid,
  CONSTRAINT admin_users_pkey PRIMARY KEY (user_id)
);
CREATE TABLE public.audit_logs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  entity text,
  entity_id text,
  action text,
  payload jsonb,
  performed_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.bookings (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  client_id uuid NOT NULL,
  provider_id uuid,
  service_id integer,
  address text,
  lat numeric,
  lng numeric,
  scheduled_at timestamp with time zone,
  hours integer DEFAULT 1,
  status character varying DEFAULT 'pending'::character varying,
  total_amount numeric DEFAULT 0,
  commission_percent numeric DEFAULT 15.0,
  commission_amount numeric DEFAULT 0,
  provider_amount numeric DEFAULT 0,
  payment_id uuid,
  dispute_deadline timestamp with time zone,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  user_id uuid,
  data timestamp with time zone,
  descricao text,
  endereco text,
  CONSTRAINT bookings_pkey PRIMARY KEY (id),
  CONSTRAINT bookings_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id),
  CONSTRAINT bookings_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.clients (
  id uuid NOT NULL,
  full_name text,
  phone text,
  city text,
  created_at timestamp with time zone DEFAULT now(),
  address_zip_code text,
  address_street text,
  address_number text,
  address_district text,
  address_state text,
  avatar_url text,
  updated_at timestamp with time zone DEFAULT now(),
  status text NOT NULL DEFAULT 'active'::text,
  blocked_at timestamp with time zone,
  block_reason text,
  email text,
  cpf text,
  profile_completed boolean NOT NULL DEFAULT false,
  address_completed boolean NOT NULL DEFAULT false,
  CONSTRAINT clients_pkey PRIMARY KEY (id),
  CONSTRAINT clients_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.conversations (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  job_id uuid,
  client_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  title text NOT NULL,
  status text NOT NULL DEFAULT 'open'::text,
  created_at timestamp with time zone DEFAULT now(),
  last_message_at timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT conversations_pkey PRIMARY KEY (id),
  CONSTRAINT conversations_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id),
  CONSTRAINT conversations_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id),
  CONSTRAINT conversations_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id)
);
CREATE TABLE public.dispute_photos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  dispute_id uuid NOT NULL,
  url text NOT NULL,
  thumb_url text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT dispute_photos_pkey PRIMARY KEY (id),
  CONSTRAINT dispute_photos_dispute_id_fkey FOREIGN KEY (dispute_id) REFERENCES public.disputes(id)
);
CREATE TABLE public.disputes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL UNIQUE,
  opened_by_user_id uuid NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['client'::text, 'provider'::text])),
  description text,
  status text NOT NULL DEFAULT 'open'::text CHECK (status = ANY (ARRAY['open'::text, 'resolved'::text, 'refunded'::text])),
  resolved_at timestamp with time zone,
  auto_refunded_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  provider_status text DEFAULT 'pending'::text CHECK (provider_status = ANY (ARRAY['pending'::text, 'viewed'::text, 'contacted'::text, 'solved'::text])),
  resolution text,
  refund_amount numeric,
  provider_id uuid NOT NULL,
  CONSTRAINT disputes_pkey PRIMARY KEY (id),
  CONSTRAINT disputes_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id),
  CONSTRAINT disputes_opened_by_user_id_fkey FOREIGN KEY (opened_by_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.job_actions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  action text NOT NULL,
  reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT job_actions_pkey PRIMARY KEY (id),
  CONSTRAINT job_actions_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id)
);
CREATE TABLE public.job_addresses (
  job_id uuid NOT NULL,
  street text,
  number text,
  district text,
  city text,
  state text,
  zipcode text,
  lat double precision,
  lng double precision,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT job_addresses_pkey PRIMARY KEY (job_id),
  CONSTRAINT job_addresses_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id)
);
CREATE TABLE public.job_candidates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'candidate'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  created_at timestamp with time zone DEFAULT now(),
  analyzed boolean NOT NULL DEFAULT false,
  approved boolean NOT NULL DEFAULT false,
  decision_status text NOT NULL DEFAULT 'pending'::text CHECK (decision_status = ANY (ARRAY['pending'::text, 'under_review'::text, 'approved'::text, 'rejected'::text])),
  client_status text NOT NULL DEFAULT 'pending'::text,
  CONSTRAINT job_candidates_pkey PRIMARY KEY (id),
  CONSTRAINT job_candidates_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id)
);
CREATE TABLE public.job_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  client_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  status text NOT NULL CHECK (status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'refunded'::text, 'cancelled'::text])),
  payment_method text,
  external_reference text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  paid_at timestamp with time zone,
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT job_payments_pkey PRIMARY KEY (id),
  CONSTRAINT job_payments_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id),
  CONSTRAINT job_payments_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id),
  CONSTRAINT job_payments_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id)
);
CREATE TABLE public.job_photos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  url text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  thumb_url text,
  CONSTRAINT job_photos_pkey PRIMARY KEY (id),
  CONSTRAINT job_photos_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id)
);
CREATE TABLE public.job_quotes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  approximate_price numeric,
  message text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  is_accepted boolean NOT NULL DEFAULT false,
  CONSTRAINT job_quotes_pkey PRIMARY KEY (id),
  CONSTRAINT job_quotes_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id),
  CONSTRAINT job_quotes_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id)
);
CREATE TABLE public.job_rejections (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  status text CHECK (status = ANY (ARRAY['cancelled_by_client'::text, 'cancelled_by_provider'::text])),
  reason text,
  client_id uuid,
  CONSTRAINT job_rejections_pkey PRIMARY KEY (id),
  CONSTRAINT job_rejections_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id),
  CONSTRAINT job_rejections_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id),
  CONSTRAINT job_rejections_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id)
);
CREATE TABLE public.job_status_history (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  old_status text,
  new_status text NOT NULL,
  changed_by uuid,
  changed_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT job_status_history_pkey PRIMARY KEY (id),
  CONSTRAINT job_status_history_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id),
  CONSTRAINT job_status_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES auth.users(id)
);
CREATE TABLE public.job_tracking (
  job_id uuid NOT NULL,
  provider_id uuid NOT NULL,
  current_lat double precision,
  current_lng double precision,
  distance_meters integer,
  eta_seconds integer,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT job_tracking_pkey PRIMARY KEY (job_id),
  CONSTRAINT job_tracking_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id),
  CONSTRAINT job_tracking_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id)
);
CREATE TABLE public.jobs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL,
  provider_id uuid,
  service_type_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  service_keyword text,
  service_detected text,
  pricing_model text CHECK (pricing_model = ANY (ARRAY['daily'::text, 'per_service'::text, 'quote'::text])),
  price numeric,
  amount_provider numeric,
  payment_method text,
  payment_method_fee numeric,
  payment_fixed_fee numeric,
  platform_fee numeric,
  scheduled_at timestamp with time zone,
  address_street text,
  address_number text,
  address_district text,
  city text,
  address_state text,
  address_zip_code text,
  status text NOT NULL DEFAULT 'waiting_providers'::text CHECK (status = ANY (ARRAY['waiting_providers'::text, 'accepted'::text, 'on_the_way'::text, 'in_progress'::text, 'completed'::text, 'cancelled_by_client'::text, 'cancelled_by_provider'::text, 'dispute'::text])),
  payout_delay_hours integer DEFAULT 24,
  hold_until timestamp with time zone,
  paid_at timestamp with time zone,
  payment_released_at timestamp with time zone,
  is_disputed boolean NOT NULL DEFAULT false,
  dispute_opened_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  category_id uuid NOT NULL,
  distance_km numeric,
  daily_quantity integer CHECK (daily_quantity >= 1),
  budget_value numeric CHECK (budget_value >= 0::numeric),
  client_budget numeric,
  client_budget_type text CHECK (client_budget_type = ANY (ARRAY['total'::text, 'per_day'::text])),
  daily_rate numeric,
  daily_total numeric,
  execution_overdue boolean NOT NULL DEFAULT false,
  execution_overdue_at timestamp with time zone,
  cancelled_at timestamp with time zone,
  job_type text,
  payment_status text DEFAULT 'pending'::text CHECK (payment_status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'refunded'::text])),
  deleted_at timestamp with time zone,
  updated_at timestamp with time zone DEFAULT now(),
  cancel_reason text,
  dispute_open boolean NOT NULL DEFAULT false,
  dispute_opened_by uuid,
  dispute_reason text,
  job_code text NOT NULL DEFAULT ('RTH-'::text || lpad((nextval('job_code_seq'::regclass))::text, 6, '0'::text)),
  is_private_job boolean NOT NULL DEFAULT false,
  private_provider_id uuid,
  private_expires_at timestamp with time zone,
  original_job_id uuid,
  dispute_status text CHECK ((dispute_status = ANY (ARRAY['resolved'::text, 'refunded'::text])) OR dispute_status IS NULL),
  accepted_at timestamp with time zone,
  on_the_way_at timestamp with time zone,
  in_progress_at timestamp with time zone,
  completed_at timestamp with time zone,
  status_updated_at timestamp with time zone,
  status_updated_by uuid,
  status_note text,
  eta_minutes integer,
  CONSTRAINT jobs_pkey PRIMARY KEY (id),
  CONSTRAINT jobs_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id),
  CONSTRAINT jobs_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id),
  CONSTRAINT jobs_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.service_categories(id),
  CONSTRAINT jobs_private_provider_id_fkey FOREIGN KEY (private_provider_id) REFERENCES public.providers(id),
  CONSTRAINT jobs_original_job_id_fkey FOREIGN KEY (original_job_id) REFERENCES public.jobs(id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  conversation_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  sender_role text NOT NULL CHECK (sender_role = ANY (ARRAY['client'::text, 'provider'::text, 'admin'::text])),
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  read_at timestamp with time zone,
  type text DEFAULT 'text'::text,
  image_url text,
  read_by_client boolean NOT NULL DEFAULT false,
  read_by_provider boolean NOT NULL DEFAULT false,
  sent_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id)
);
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  title text,
  body text,
  data jsonb,
  channel character varying DEFAULT 'app'::character varying,
  read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  read_at timestamp with time zone,
  deleted_at timestamp with time zone,
  type text,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.partner_banners (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  image_path text NOT NULL,
  action_type text CHECK ((action_type = ANY (ARRAY['service_category'::text, 'partner_store'::text, 'url'::text])) OR action_type IS NULL),
  action_value text,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT partner_banners_pkey PRIMARY KEY (id)
);
CREATE TABLE public.partner_store_products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  name text NOT NULL,
  description text,
  price numeric,
  image_url text,
  is_active boolean DEFAULT true,
  sort_order integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT partner_store_products_pkey PRIMARY KEY (id),
  CONSTRAINT partner_store_products_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.partner_stores(id)
);
CREATE TABLE public.partner_stores (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  short_description text,
  address text,
  city text,
  state text,
  cover_image_url text,
  gallery_images ARRAY DEFAULT '{}'::text[],
  highlight_products ARRAY DEFAULT '{}'::text[],
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  latitude numeric,
  longitude numeric,
  CONSTRAINT partner_stores_pkey PRIMARY KEY (id)
);
CREATE TABLE public.payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  client_id uuid NOT NULL,
  provider_id uuid,
  amount_total numeric NOT NULL,
  amount_provider numeric NOT NULL,
  amount_platform numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL,
  gateway text NOT NULL DEFAULT 'pagarme'::text,
  gateway_transaction_id text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'refunded'::text])),
  paid_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  refund_amount numeric,
  refunded_at timestamp with time zone,
  quote_id uuid,
  gateway_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamp with time zone,
  CONSTRAINT payments_pkey PRIMARY KEY (id),
  CONSTRAINT payments_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id),
  CONSTRAINT payments_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id),
  CONSTRAINT payments_quote_id_fkey FOREIGN KEY (quote_id) REFERENCES public.job_quotes(id),
  CONSTRAINT payments_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name text,
  phone text,
  role text DEFAULT 'cliente'::text CHECK (lower(role) = ANY (ARRAY['client'::text, 'provider'::text, 'cliente'::text, 'prestador'::text])),
  created_at timestamp with time zone DEFAULT now(),
  avatar_url text,
  rating numeric,
  city text,
  bio text,
  is_verified boolean DEFAULT false,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.provider_approved_notifications (
  provider_id uuid NOT NULL,
  job_id uuid NOT NULL,
  viewed boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT provider_approved_notifications_pkey PRIMARY KEY (provider_id, job_id),
  CONSTRAINT provider_approved_notifications_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id),
  CONSTRAINT provider_approved_notifications_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id)
);
CREATE TABLE public.provider_documents (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL,
  document_type text NOT NULL,
  document_number text,
  url text NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text,
  rejection_reason text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT provider_documents_pkey PRIMARY KEY (id),
  CONSTRAINT provider_documents_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id)
);
CREATE TABLE public.provider_service_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL,
  service_type_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT provider_service_types_pkey PRIMARY KEY (id),
  CONSTRAINT provider_service_types_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id),
  CONSTRAINT provider_service_types_service_type_id_fkey FOREIGN KEY (service_type_id) REFERENCES public.service_types(id)
);
CREATE TABLE public.provider_services (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL,
  subcategory_id uuid NOT NULL,
  has_fixed_price boolean DEFAULT false,
  fixed_price numeric,
  fixed_price_type text CHECK (fixed_price_type = ANY (ARRAY['daily'::text, 'service'::text])),
  allow_quote boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT provider_services_pkey PRIMARY KEY (id),
  CONSTRAINT provider_services_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES auth.users(id)
);
CREATE TABLE public.provider_wallets (
  provider_id uuid NOT NULL,
  available_balance numeric NOT NULL DEFAULT 0,
  pending_balance numeric NOT NULL DEFAULT 0,
  disputed_balance numeric NOT NULL DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT provider_wallets_pkey PRIMARY KEY (provider_id),
  CONSTRAINT provider_wallets_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id)
);
CREATE TABLE public.providers (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL UNIQUE,
  cpf_cnpj character varying,
  categories ARRAY DEFAULT ARRAY[]::text[],
  bio text,
  rating numeric DEFAULT 0,
  verified boolean DEFAULT false,
  status character varying DEFAULT 'pending'::character varying,
  lat numeric,
  lng numeric,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  has_configured_services boolean DEFAULT false,
  full_name text,
  city text,
  avatar_url text,
  is_online boolean DEFAULT false,
  documents_verified boolean NOT NULL DEFAULT false,
  onboarding_completed boolean NOT NULL DEFAULT false,
  phone text,
  default_price numeric,
  default_provider_amount numeric,
  payment_percent_fee numeric,
  payment_fixed_fee numeric,
  address_street text,
  address_number text,
  address_complement text,
  address_neighborhood text,
  address_city text,
  address_state text,
  address_cep text,
  address_district text,
  cep text,
  state text,
  is_verified boolean NOT NULL DEFAULT false,
  blocked_at timestamp with time zone,
  block_reason text,
  pagarme_recipient_id text,
  CONSTRAINT providers_pkey PRIMARY KEY (id)
);
CREATE TABLE public.renthus_home_services (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  image_url text,
  service_keyword text,
  display_order integer DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamp without time zone DEFAULT now(),
  thumb_url text,
  order_index integer DEFAULT 0,
  CONSTRAINT renthus_home_services_pkey PRIMARY KEY (id)
);
CREATE TABLE public.reviews (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  booking_id uuid,
  from_user uuid,
  to_user uuid,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT reviews_pkey PRIMARY KEY (id),
  CONSTRAINT reviews_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id)
);
CREATE TABLE public.service_categories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  icon text,
  sort_order integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT service_categories_pkey PRIMARY KEY (id)
);
CREATE TABLE public.service_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  payout_delay_hours integer NOT NULL DEFAULT 24,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  category_id uuid,
  description text,
  sort_order integer,
  icon text,
  CONSTRAINT service_types_pkey PRIMARY KEY (id),
  CONSTRAINT service_types_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.service_categories(id)
);
CREATE TABLE public.user_devices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  fcm_token text NOT NULL,
  platform text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  device_token text,
  CONSTRAINT user_devices_pkey PRIMARY KEY (id),
  CONSTRAINT user_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_onboarding (
  user_id uuid NOT NULL,
  intended_role text CHECK (intended_role = ANY (ARRAY['client'::text, 'provider'::text])),
  status text NOT NULL DEFAULT 'started'::text CHECK (status = ANY (ARRAY['started'::text, 'signup_submitted'::text, 'email_confirmed'::text, 'step2_started'::text, 'completed'::text])),
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  signup_submitted_at timestamp with time zone,
  email_confirmed_at timestamp with time zone,
  step2_started_at timestamp with time zone,
  completed_at timestamp with time zone,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  referrer text,
  platform text,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_onboarding_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_onboarding_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_push_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE,
  token text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_push_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT user_push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_roles (
  user_id uuid NOT NULL,
  role USER-DEFINED NOT NULL,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_roles_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.waitlist_registrations (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  full_name text NOT NULL,
  whatsapp text NOT NULL,
  city text,
  role text CHECK (role = ANY (ARRAY['client'::text, 'provider'::text])),
  services text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT waitlist_registrations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.wallets (
  user_id uuid NOT NULL,
  balance numeric DEFAULT 0,
  pending_balance numeric DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT wallets_pkey PRIMARY KEY (user_id)
);
CREATE TABLE public.withdrawals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL,
  amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text,
  pix_key text,
  pix_key_type text,
  requested_at timestamp with time zone DEFAULT now(),
  processed_at timestamp with time zone,
  error_message text,
  CONSTRAINT withdrawals_pkey PRIMARY KEY (id),
  CONSTRAINT withdrawals_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id)
);


CREATE OR REPLACE FUNCTION public.add_audit_log(_entity text, _entity_id uuid, _action text, _payload jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.audit_logs (
    entity,
    entity_id,
    action,
    payload,
    performed_by
  )
  values (
    _entity,
    _entity_id,
    _action,
    _payload,
    auth.uid()  -- pode ser null em chamadas com service role
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.add_job_photo(p_job_id uuid, p_url text, p_thumb_url text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid;
  v_client_id uuid;
  v_provider_id uuid;
  v_status text;
  v_count int;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_job_id is null then
    raise exception 'job_id_missing';
  end if;

  if p_url is null or length(trim(p_url)) < 10 then
    raise exception 'invalid_url';
  end if;

  -- Busca dados do job
  select j.client_id, j.provider_id, j.status
    into v_client_id, v_provider_id, v_status
  from public.jobs j
  where j.id = p_job_id;

  if v_client_id is null then
    raise exception 'job_not_found';
  end if;

  -- SOMENTE CLIENTE
  if v_user_id <> v_client_id then
    raise exception 'not_allowed';
  end if;

  -- SOMENTE ANTES DO MATCH
  if v_provider_id is not null then
    raise exception 'cannot_add_photos_after_match';
  end if;

  -- SOMENTE waiting_providers
  if v_status <> 'waiting_providers' then
    raise exception 'cannot_add_photos_in_this_status';
  end if;

  -- LIMITE 3
  select count(*) into v_count
  from public.job_photos jp
  where jp.job_id = p_job_id;

  if v_count >= 3 then
    raise exception 'max_photos_reached';
  end if;

  -- Insere registro
  insert into public.job_photos (job_id, url, thumb_url, created_at)
  values (
    p_job_id,
    trim(p_url),
    nullif(trim(p_thumb_url), ''),
    now()
  );

  return;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_audit(p_entity text, p_entity_id text, p_action text, p_payload jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.audit_logs (entity, entity_id, action, payload, performed_by)
  values (p_entity, p_entity_id, p_action, p_payload, auth.uid());
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_force_cancel_job(p_job_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_admin() then
    raise exception 'admin only';
  end if;

  update public.jobs
     set status = 'cancelled',
         cancelled_at = now(),
         cancel_reason = coalesce(p_reason, cancel_reason),
         updated_at = now()
   where id = p_job_id;

  insert into public.audit_logs(entity, entity_id, action, payload, performed_by)
  values ('jobs', p_job_id::text, 'admin_force_cancel',
          jsonb_build_object('reason', p_reason),
          auth.uid());
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_force_complete_job(p_job_id uuid, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not is_admin() then
    raise exception 'admin only';
  end if;

  update public.jobs
     set status = 'completed',
         updated_at = now()
   where id = p_job_id;

  insert into public.audit_logs(entity, entity_id, action, payload, performed_by)
  values ('jobs', p_job_id::text, 'admin_force_complete',
          jsonb_build_object('note', p_note),
          auth.uid());
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_grant_admin(p_user_id uuid, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then
    raise exception 'not allowed';
  end if;

  insert into public.admin_users(user_id, note, created_by)
  values (p_user_id, p_note, auth.uid())
  on conflict (user_id) do update
    set note = excluded.note;

  perform public.admin_audit(
    'admin_users',
    p_user_id::text,
    'grant_admin',
    jsonb_build_object('note', p_note)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_insert_test_booking(client_email text, provider_email text)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE c uuid;
DECLARE p uuid;
DECLARE s int;
DECLARE b uuid;
BEGIN
  SELECT id INTO c FROM users WHERE email = client_email LIMIT 1;
  SELECT id INTO p FROM users WHERE email = provider_email LIMIT 1;
  IF c IS NULL OR p IS NULL THEN
    RAISE NOTICE 'Client or provider not found';
    RETURN NULL;
  END IF;
  SELECT id INTO s FROM services_catalog LIMIT 1;
  INSERT INTO providers (user_id, status, lat, lng) VALUES (p, 'active', -13.5, -55.5) ON CONFLICT DO NOTHING;
  INSERT INTO provider_services (provider_id, service_id, price_override) VALUES ((SELECT id FROM providers WHERE user_id = p LIMIT 1), s, 150.00) ON CONFLICT DO NOTHING;
  INSERT INTO bookings (client_id, provider_id, service_id, address, scheduled_at, total_amount) VALUES (c, (SELECT id FROM providers WHERE user_id = p LIMIT 1), s, 'Rua Teste, 123', now() + interval '1 hour', 150.00) RETURNING id INTO b;
  RETURN b;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_open_dispute(p_job_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dispute_id uuid;
begin
  if not is_admin() then
    raise exception 'admin only';
  end if;

  insert into public.disputes(job_id, opened_by_user_id, role, description, status, created_at)
  values (p_job_id, auth.uid(), 'admin', coalesce(p_reason,'Disputa aberta pelo admin'), 'open', now())
  returning id into v_dispute_id;

  update public.jobs
     set status = 'dispute',
         is_disputed = true,
         dispute_open = true,
         dispute_opened_at = now(),
         dispute_reason = coalesce(p_reason, dispute_reason),
         updated_at = now()
   where id = p_job_id;

  insert into public.audit_logs(entity, entity_id, action, payload, performed_by)
  values ('disputes', v_dispute_id::text, 'admin_open_dispute',
          jsonb_build_object('job_id', p_job_id, 'reason', p_reason),
          auth.uid());

  return v_dispute_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_dispute_status(p_dispute_id uuid, p_new_status text, p_resolution text DEFAULT NULL::text, p_refund_amount numeric DEFAULT NULL::numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job_id uuid;
begin
  if not public.is_admin() then
    raise exception 'not allowed';
  end if;

  select job_id into v_job_id
  from public.disputes
  where id = p_dispute_id;

  if v_job_id is null then
    raise exception 'dispute not found';
  end if;

  update public.disputes
     set status = p_new_status,
         resolved_at = case when p_new_status in ('resolved','refunded') then now() else resolved_at end,
         resolution = coalesce(p_resolution, resolution),
         refund_amount = coalesce(p_refund_amount, refund_amount),
         auto_refunded_at = case when p_new_status = 'refunded' then now() else auto_refunded_at end
   where id = p_dispute_id;

  -- sincroniza job (mínimo)
  if p_new_status = 'refunded' then
    update public.jobs
       set dispute_open = false,
           is_disputed = true,
           payment_status = 'refunded'
     where id = v_job_id;
  elsif p_new_status = 'resolved' then
    update public.jobs
       set dispute_open = false,
           is_disputed = true
     where id = v_job_id;
  end if;

  perform public.admin_audit(
    'disputes',
    p_dispute_id::text,
    'set_status',
    jsonb_build_object(
      'new_status', p_new_status,
      'resolution', p_resolution,
      'refund_amount', p_refund_amount
    )
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_payment_status(p_payment_id uuid, p_new_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_admin() then
    raise exception 'not allowed';
  end if;

  update public.payments
     set status = p_new_status,
         paid_at = case when p_new_status = 'approved' then coalesce(paid_at, now()) else paid_at end
   where id = p_payment_id;

  perform public.admin_audit(
    'payments',
    p_payment_id::text,
    'set_status',
    jsonb_build_object('new_status', p_new_status)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_user_block(p_user_id uuid, p_block boolean, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_now timestamptz := now();
begin
  if not public.is_admin() then
    raise exception 'not allowed';
  end if;

  -- clients: id = auth.uid (no seu modelo, client.id é o user_id)
  update public.clients
     set status = case when p_block then 'blocked' else 'active' end,
         blocked_at = case when p_block then v_now else null end,
         block_reason = case when p_block then p_reason else null end
   where id = p_user_id;

  -- providers: provider.user_id = auth.uid
  update public.providers
     set status = case when p_block then 'blocked' else 'active' end,
         blocked_at = case when p_block then v_now else null end,
         block_reason = case when p_block then p_reason else null end
   where user_id = p_user_id;

  perform public.admin_audit(
    'users',
    p_user_id::text,
    case when p_block then 'block' else 'unblock' end,
    jsonb_build_object('reason', p_reason)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_upsert_partner_store(p_id uuid, p_name text, p_short_description text, p_address text, p_city text, p_state text, p_cover_image_url text, p_gallery_images text[], p_highlight_products text[], p_latitude numeric, p_longitude numeric, p_is_active boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  if p_id is null then
    insert into public.partner_stores (
      name,
      short_description,
      address,
      city,
      state,
      cover_image_url,
      gallery_images,
      highlight_products,
      latitude,
      longitude,
      is_active
    ) values (
      p_name,
      p_short_description,
      p_address,
      p_city,
      p_state,
      p_cover_image_url,
      coalesce(p_gallery_images, '{}'),
      coalesce(p_highlight_products, '{}'),
      p_latitude,
      p_longitude,
      coalesce(p_is_active, true)
    )
    returning id into v_id;
  else
    update public.partner_stores
    set
      name = p_name,
      short_description = p_short_description,
      address = p_address,
      city = p_city,
      state = p_state,
      cover_image_url = p_cover_image_url,
      gallery_images = coalesce(p_gallery_images, '{}'),
      highlight_products = coalesce(p_highlight_products, '{}'),
      latitude = p_latitude,
      longitude = p_longitude,
      is_active = coalesce(p_is_active, true)
    where id = p_id
    returning id into v_id;
  end if;

  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.apply_payment_paid_effects()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- Só roda quando status mudar para 'paid'
  if (tg_op = 'UPDATE') then
    if (old.status = new.status) then
      return new;
    end if;
  end if;

  if (new.status <> 'paid') then
    return new;
  end if;

  -- 1) Atualiza JOB com dados do pagamento
  update public.jobs j
  set
    payment_status = 'paid',
    price = new.amount_total,
    amount_provider = new.amount_provider, -- ✅ corrigido
    provider_id = new.provider_id,
    paid_at = coalesce(new.paid_at, now()),
    payment_method = new.payment_method,
    status = 'accepted'
  where j.id = new.job_id;

  -- 2) Aceita a quote correspondente ao provider do pagamento
  update public.job_quotes q
  set is_accepted = true
  where q.job_id = new.job_id
    and q.provider_id = new.provider_id;

  -- 3) Marca candidatos
  update public.job_candidates c
  set
    approved = true,
    analyzed = true,
    decision_status = 'approved',
    client_status = 'approved'
  where c.job_id = new.job_id
    and c.provider_id = new.provider_id;

  update public.job_candidates c
  set
    approved = false,
    analyzed = true,
    decision_status = 'rejected',
    client_status = 'rejected'
  where c.job_id = new.job_id
    and c.provider_id <> new.provider_id;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.auto_refund_expired_disputes()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r        record;
  v_count  integer := 0;
begin
  -- Segurança extra: só service_role deve chamar
  if auth.role() is distinct from 'service_role' then
    raise exception 'Função reservada para o serviço interno.';
  end if;

  -- Percorre todas as disputas abertas com prazo vencido
  for r in
    select id, job_id
    from public.disputes
    where status = 'open'
      and response_deadline_at is not null
      and response_deadline_at <= now()
      and auto_refunded_at is null
  loop
    -- Marca disputa como auto_refunded
    update public.disputes
    set
      status           = 'auto_refunded',
      auto_refunded_at = now(),
      resolved_at      = now()
    where id = r.id;

    -- Atualiza o job para "refunded"
    update public.jobs
    set status = 'refunded'
    where id = r.job_id;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.auto_release_payment()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE wallets w
  SET balance = balance + b.amount_provider,        -- ✅ corrigido
      pending_balance = pending_balance - b.amount_provider,
      updated_at = now()
  FROM bookings b
  WHERE b.status = 'paid'
    AND b.dispute_deadline < now()
    AND NOT EXISTS (
      SELECT 1
      FROM disputes d
      WHERE d.booking_id = b.id
        AND d.status IN ('pending', 'under_review')
    );

  UPDATE bookings
  SET status = 'completed',
      updated_at = now()
  WHERE status = 'paid'
    AND dispute_deadline < now()
    AND NOT EXISTS (
      SELECT 1
      FROM disputes d
      WHERE d.booking_id = bookings.id
        AND d.status IN ('pending', 'under_review')
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.become_candidate(p_job_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_status text;
begin
  -- Job precisa existir e estar aguardando providers
  select status into v_status
  from public.jobs
  where id = p_job_id;

  if v_status is null then
    raise exception 'Job não encontrado';
  end if;

  if v_status <> 'waiting_providers' then
    raise exception 'Não é possível candidatar neste status: %', v_status;
  end if;

  -- Evita candidatura duplicada
  if exists (
    select 1 from public.job_candidates
    where job_id = p_job_id and provider_id = auth.uid()
  ) then
    raise exception 'Você já é candidato neste job';
  end if;

  insert into public.job_candidates (job_id, provider_id, created_at)
  values (p_job_id, auth.uid(), now());
end;
$function$
;

CREATE OR REPLACE FUNCTION public.bytea_to_text(data bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/http', $function$bytea_to_text$function$
;

CREATE OR REPLACE FUNCTION public.calc_payment_split()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- garante amount_total válido
  if new.amount_total is null or new.amount_total <= 0 then
    raise exception 'amount_total inválido';
  end if;

  -- 15% plataforma
  new.amount_platform := round(new.amount_total * 0.15, 2);

  -- 85% provider
  new.amount_provider := new.amount_total - new.amount_platform;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.call_edge_function_send_push()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- função legacy desativada: não faz mais chamadas HTTP
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_job(_job_id uuid, _user_id uuid, _role text, _reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_job           jobs%ROWTYPE;
  v_new_status    text;
  v_now           timestamptz := now();
  v_other_user_id uuid;
BEGIN
  -- 1) Busca o job
  SELECT *
  INTO v_job
  FROM jobs
  WHERE id = _job_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Job não encontrado.' USING errcode = 'P0001';
  END IF;

  -- 2) Verifica se ainda pode cancelar
  IF v_job.status IN (
    'in_progress',
    'completed',
    'cancelled_by_client',
    'cancelled_by_provider',
    'dispute_open',
    'refunded'
  ) THEN
    RAISE EXCEPTION
      'Este pedido não pode mais ser cancelado no status atual (%).',
      v_job.status
      USING errcode = 'P0001';
  END IF;

  -- 3) Valida quem está cancelando e define novo status
  IF _role = 'client' THEN
    IF v_job.client_id IS NULL OR v_job.client_id <> _user_id THEN
      RAISE EXCEPTION 'Você não é o cliente deste pedido.' USING errcode = 'P0001';
    END IF;

    v_new_status    := 'cancelled_by_client';
    v_other_user_id := v_job.provider_id;  -- notifica o prestador

  ELSIF _role = 'provider' THEN
    IF v_job.provider_id IS NULL OR v_job.provider_id <> _user_id THEN
      RAISE EXCEPTION 'Você não é o prestador deste pedido.' USING errcode = 'P0001';
    END IF;

    v_new_status    := 'cancelled_by_provider';
    v_other_user_id := v_job.client_id;    -- notifica o cliente

  ELSE
    RAISE EXCEPTION 'Role inválida. Use "client" ou "provider".'
      USING errcode = 'P0001';
  END IF;

  -- 4) Atualiza o job
  UPDATE jobs
  SET status       = v_new_status,
      cancelled_at = COALESCE(cancelled_at, v_now)
  WHERE id = _job_id;

  -- 5) Registra ação em job_actions
  INSERT INTO job_actions (job_id, provider_id, action, reason, created_at)
  VALUES (
    _job_id,
    v_job.provider_id,   -- sempre o prestador ligado ao job
    v_new_status,
    _reason,
    v_now
  );

  -- 6) Cria notificação para a outra parte
  IF v_other_user_id IS NOT NULL THEN
    INSERT INTO notifications (
      user_id,
      title,
      body,
      data,
      channel,
      read,
      created_at
    )
    VALUES (
      v_other_user_id,
      'Pedido cancelado',
      CASE
        WHEN _role = 'client' THEN 'O cliente cancelou o pedido.'
        ELSE 'O profissional cancelou o pedido.'
      END,
      json_build_object(
        'job_id', _job_id,
        'status', v_new_status
      ),
      'app',
      FALSE,
      v_now
    );
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_job_as_client(p_job_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job record;
begin
  select id, client_id, status
    into v_job
  from public.jobs
  where id = p_job_id;

  if v_job.id is null then
    raise exception 'Job não encontrado';
  end if;

  if v_job.client_id <> auth.uid() then
    raise exception 'Sem permissão: job não pertence a este client';
  end if;

  if v_job.status not in ('waiting_providers','accepted','on_the_way') then
    raise exception 'Cancelamento não permitido no status: %', v_job.status;
  end if;

  update public.jobs
  set status = 'cancelled',
      updated_at = now()
  where id = p_job_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.check_dispute_photos_limit()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_client_count   int;
  v_provider_count int;
begin
  -- conta fotos do cliente
  select count(*) into v_client_count
  from public.dispute_photos
  where dispute_id = NEW.dispute_id
    and url like '%/client/%';

  -- conta fotos do prestador
  select count(*) into v_provider_count
  from public.dispute_photos
  where dispute_id = NEW.dispute_id
    and url like '%/provider/%';

  -- se for foto do cliente
  if NEW.url like '%/client/%' then
    if v_client_count >= 5 then
      raise exception using
        message = 'Limite de 5 fotos do cliente para esta reclamação já foi atingido.',
        errcode = 'P0001';
    end if;
  end if;

  -- se for foto do prestador
  if NEW.url like '%/provider/%' then
    if v_provider_count >= 5 then
      raise exception using
        message = 'Limite de 5 fotos do prestador para esta reclamação já foi atingido.',
        errcode = 'P0001';
    end if;
  end if;

  -- proteção extra: total máximo (10)
  if (v_client_count + v_provider_count) >= 10 then
    raise exception using
      message = 'Limite total de 10 fotos por reclamação foi atingido.',
      errcode = 'P0001';
  end if;

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.check_jobs_candidates_24h()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record;
  v_cand_count int;
begin
  for r in
    select j.id, j.client_id, j.created_at
    from public.jobs j
    where j.status = 'waiting_providers'
      and j.client_id is not null
      and j.created_at <= now() - interval '24 hours'
  loop
    select count(*) into v_cand_count
    from public.job_candidates c
    where c.job_id = r.id;

    -- Se tiver 0 candidatos, nunca notificar
    if v_cand_count <= 0 then
      continue;
    end if;

    -- Se já tiver notificação 24h pra esse job, pula
    if exists (
      select 1
      from public.notifications n
      where n.user_id = r.client_id
        and n.type = 'job_candidates_24h'
        and n.data ->> 'job_id' = r.id::text
    ) then
      continue;
    end if;

    insert into public.notifications (user_id, type, title, body, data)
    values (
      r.client_id,
      'job_candidates_24h',
      'Seu pedido ainda está em aberto',
      'Seu serviço está há mais de 24 horas aguardando análise. Veja as propostas disponíveis.',
      jsonb_build_object(
        'job_id', r.id,
        'candidate_count', v_cand_count
      )
    );
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.client_ensure_profile()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_role public.user_role;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- Role atual (se existir)
  select ur.role into v_role
  from public.user_roles ur
  where ur.user_id = auth.uid();

  -- Se já é provider, não deixa virar client
  if v_role = 'provider' then
    raise exception 'Usuário já cadastrado como prestador';
  end if;

  -- Se não tem role, cria como client
  if v_role is null then
    insert into public.user_roles(user_id, role)
    values (auth.uid(), 'client')
    on conflict (user_id) do nothing;
  end if;

  -- Garante client
  insert into public.clients(id)
  values (auth.uid())
  on conflict (id) do nothing;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.close_job_dispute(p_job_id uuid, p_resolution text DEFAULT NULL::text)
 RETURNS jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_job public.jobs%rowtype;
begin
  -- 1) Busca job
  select *
  into v_job
  from public.jobs
  where id = p_job_id;

  if v_job.id is null then
    raise exception 'Job % não encontrado', p_job_id;
  end if;

  -- 2) Só o CLIENTE pode encerrar disputa
  if v_job.client_id is distinct from auth.uid() then
    raise exception 'Somente o cliente pode encerrar a disputa deste serviço.';
  end if;

  -- 3) Se não tiver disputa aberta, só retorna
  if coalesce(v_job.dispute_open, false) is not true then
    return v_job;
  end if;

  -- 4) Fecha disputa
  update public.jobs
  set dispute_open = false
  where id = p_job_id
  returning * into v_job;

  -- 5) Atualiza conversas (opcional, pra status visual)
  update public.conversations c
  set status = 'closed'
  where c.job_id = p_job_id
    and c.status = 'dispute';

  -- 6) Log em audit_logs
  insert into public.audit_logs (
    entity,
    entity_id,
    action,
    payload,
    performed_by,
    created_at
  )
  values (
    'job',
    v_job.id,
    'dispute_closed',
    jsonb_build_object('resolution', p_resolution),
    auth.uid(),
    now()
  );

  return v_job;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_job(p_service_type_id uuid, p_category_id uuid, p_title text, p_description text, p_service_detected text, p_street text, p_number text, p_district text, p_city text, p_state text, p_zipcode text DEFAULT NULL::text, p_lat double precision DEFAULT NULL::double precision, p_lng double precision DEFAULT NULL::double precision)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_client_id uuid;
  v_job_id uuid;
begin
  -- ==========================================================
  -- Validação de autenticação
  -- ==========================================================
  v_client_id := auth.uid();
  if v_client_id is null then
    raise exception 'not_authenticated';
  end if;

  -- ==========================================================
  -- Validações mínimas
  -- ==========================================================
  if p_service_type_id is null then
    raise exception 'service_type_id_missing';
  end if;

  if p_category_id is null then
    raise exception 'category_id_missing';
  end if;

  if p_title is null or length(trim(p_title)) < 3 then
    raise exception 'invalid_title';
  end if;

  if p_description is null or length(trim(p_description)) < 30 then
    raise exception 'description_too_short';
  end if;

  -- ==========================================================
  -- INSERT: jobs
  -- ==========================================================
  insert into public.jobs (
    client_id,
    service_type_id,
    category_id,
    title,
    description,
    service_detected,
    status,
    created_at,
    updated_at
  )
  values (
    v_client_id,
    p_service_type_id,
    p_category_id,
    left(trim(p_title), 80),
    left(trim(p_description), 800),
    nullif(trim(p_service_detected), ''),
    'waiting_providers',
    now(),
    now()
  )
  returning id into v_job_id;

  -- ==========================================================
  -- INSERT: job_addresses
  -- ==========================================================
  insert into public.job_addresses (
    job_id,
    street,
    number,
    district,
    city,
    state,
    zipcode,
    lat,
    lng,
    created_at
  )
  values (
    v_job_id,
    nullif(trim(p_street), ''),
    nullif(trim(p_number), ''),
    nullif(trim(p_district), ''),
    nullif(trim(p_city), ''),
    nullif(trim(p_state), ''),
    nullif(trim(p_zipcode), ''),
    p_lat,
    p_lng,
    now()
  );

  return v_job_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_job_quote(p_job_id uuid, p_approximate_price numeric, p_message text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_status text;
begin
  -- Job precisa existir e estar aguardando providers
  select status into v_status
  from public.jobs
  where id = p_job_id;

  if v_status is null then
    raise exception 'Job não encontrado';
  end if;

  if v_status <> 'waiting_providers' then
    raise exception 'Não é possível enviar proposta neste status: %', v_status;
  end if;

  -- Só pode enviar proposta se for candidato
  if not exists (
    select 1
    from public.job_candidates
    where job_id = p_job_id
      and provider_id = auth.uid()
  ) then
    raise exception 'Você precisa ser candidato antes de enviar proposta';
  end if;

  -- Evita duplicar proposta
  if exists (
    select 1
    from public.job_quotes
    where job_id = p_job_id
      and provider_id = auth.uid()
  ) then
    raise exception 'Você já enviou uma proposta para este job';
  end if;

  insert into public.job_quotes (
    job_id, provider_id, approximate_price, message, created_at
  )
  values (
    p_job_id, auth.uid(), p_approximate_price, p_message, now()
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_notification(p_user_id uuid, p_title text, p_body text, p_channel text DEFAULT 'app'::text, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  insert into public.notifications (id, user_id, title, body, channel, data, read, created_at)
  values (
    gen_random_uuid(),
    p_user_id,
    p_title,
    p_body,
    p_channel,
    coalesce(p_data, '{}'::jsonb),
    false,
    now()
  );
$function$
;

CREATE OR REPLACE FUNCTION public.create_private_job_from_existing(p_job_id uuid, p_client_id uuid)
 RETURNS jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_old jobs;
  v_new jobs;
begin
  -- 1) carrega job original garantindo que pertence ao cliente
  select *
  into v_old
  from public.jobs
  where id = p_job_id
    and client_id = p_client_id;

  if not found then
    raise exception 'Job não encontrado ou não pertence a este cliente.';
  end if;

  if v_old.provider_id is null then
    raise exception 'Job original não possui prestador definido.';
  end if;

  -- 2) cria novo job copiando dados principais
  insert into public.jobs (
    client_id,
    service_type_id,
    category_id,
    title,
    description,
    pricing_model,
    daily_quantity,
    daily_rate,
    client_budget,
    city,
    address_state,
    -- demais campos que fizer sentido copiar (ajuste conforme seu schema)
    status,
    payment_status,
    is_private_job,
    private_provider_id,
    private_expires_at,
    original_job_id
  )
  values (
    v_old.client_id,
    v_old.service_type_id,
    v_old.category_id,
    v_old.title,
    v_old.description,
    v_old.pricing_model,
    v_old.daily_quantity,
    v_old.daily_rate,
    v_old.client_budget,
    v_old.city,
    v_old.address_state,
    'waiting_providers',      -- novo pedido aberto
    'pending',                -- ainda sem pagamento
    true,                     -- é privado
    v_old.provider_id,        -- mesmo prestador do job original
    now() + interval '4 hours', -- exclusivo por 4 horas
    v_old.id                  -- referência ao job original
  )
  returning * into v_new;

  return v_new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.create_private_job_from_existing(p_job_id uuid)
 RETURNS jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_old jobs;
  v_new jobs;
begin
  -- 1) carrega job original, garantindo que pertence ao cliente logado
  select *
    into v_old
    from public.jobs
   where id = p_job_id
     and client_id = auth.uid();

  if not found then
    raise exception 'Job não encontrado ou não pertence a este cliente.';
  end if;

  if v_old.provider_id is null then
    raise exception 'Job original não possui prestador definido.';
  end if;

  -- 2) cria novo job copiando campos principais
  insert into public.jobs (
    client_id,
    service_type_id,
    category_id,
    title,
    description,
    pricing_model,
    daily_quantity,
    daily_rate,
    client_budget,
    city,
    address_state,
    scheduled_at,
    status,
    payment_status,
    is_private_job,
    private_provider_id,
    private_expires_at,
    original_job_id
  )
  values (
    v_old.client_id,
    v_old.service_type_id,
    v_old.category_id,
    v_old.title,
    v_old.description,
    v_old.pricing_model,
    v_old.daily_quantity,
    v_old.daily_rate,
    v_old.client_budget,
    v_old.city,
    v_old.address_state,
    null,                         -- cliente escolhe nova data (ajuste se quiser copiar)
    'waiting_providers',          -- novo pedido aberto
    'pending',                    -- ainda sem pagamento
    true,                         -- é privado
    v_old.provider_id,            -- mesmo prestador
    now() + interval '4 hours',   -- exclusividade 4h
    v_old.id                      -- referência ao job original
  )
  returning * into v_new;

  return v_new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.current_provider_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.id
  from public.providers p
  where p.user_id = auth.uid()
  limit 1
$function$
;

CREATE OR REPLACE FUNCTION public.enforce_job_quotes_accept_only()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- Bloqueia mudanças em qualquer coluna que não seja is_accepted
  if (new.job_id is distinct from old.job_id)
     or (new.provider_id is distinct from old.provider_id)
     or (new.approximate_price is distinct from old.approximate_price)
     or (new.message is distinct from old.message)
     or (new.created_at is distinct from old.created_at) then
    raise exception 'Você só pode aceitar a proposta (alterar is_accepted).';
  end if;

  -- Só permite transição false -> true
  if old.is_accepted = true then
    raise exception 'Esta proposta já foi aceita e não pode ser alterada.';
  end if;

  if new.is_accepted is distinct from true then
    raise exception 'Você só pode marcar a proposta como aceita (is_accepted=true).';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_job_allows_chat()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_job_status text;
BEGIN
  -- pega o status do job da conversa
  SELECT j.status
  INTO v_job_status
  FROM public.conversations c
  JOIN public.jobs j ON j.id = c.job_id
  WHERE c.id = NEW.conversation_id;

  -- se não achou job, não trava (caso raro)
  IF v_job_status IS NULL THEN
    RETURN NEW;
  END IF;

  -- libera chat nos status normais E em 'dispute'
  IF v_job_status IN ('accepted', 'on_the_way', 'in_progress', 'dispute') THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Chat indisponível para o status atual do serviço: %', v_job_status
    USING errcode = 'P0001';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_job_chat_allowed()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_job_id uuid;
  v_job_status text;
  v_has_open_dispute boolean;
BEGIN
  -- Descobre o job ligado à conversa
  SELECT job_id
  INTO v_job_id
  FROM public.conversations
  WHERE id = NEW.conversation_id;

  IF v_job_id IS NULL THEN
    RAISE EXCEPTION 'Conversa não encontrada para esta mensagem.';
  END IF;

  -- Status atual do job
  SELECT status
  INTO v_job_status
  FROM public.jobs
  WHERE id = v_job_id;

  -- Se não tiver status, não bloqueia
  IF v_job_status IS NULL THEN
    RETURN NEW;
  END IF;

  -- Existe disputa aberta para este job?
  SELECT EXISTS (
    SELECT 1
    FROM public.disputes d
    WHERE d.job_id = v_job_id
      AND d.status = 'open'
  )
  INTO v_has_open_dispute;

  -- Regras:
  --  - Se status NÃO estiver na lista bloqueada -> libera
  --  - OU se status = 'dispute'              -> libera
  --  - OU se houver disputa aberta           -> libera
  IF v_job_status NOT IN ('completed', 'cancelled_by_client', 'cancelled_by_provider', 'refunded')
     OR v_job_status = 'dispute'
     OR v_has_open_dispute THEN
    RETURN NEW;
  END IF;

  -- Só chega aqui se estiver em status bloqueado E sem disputa aberta
  RAISE EXCEPTION
    'Chat indisponível para o status atual do serviço: %',
    v_job_status;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_job_chat_allowed(p_conversation_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job_status text;
begin
  -- Busca o status do job ligado à conversa
  select j.status
    into v_job_status
  from public.conversations c
  join public.jobs j on j.id = c.job_id
  where c.id = p_conversation_id;

  -- Se não achar nada, não bloqueia (evita erro chato)
  if v_job_status is null then
    return;
  end if;

  -- 🔒 BLOQUEIA APENAS esses status:
  if v_job_status in ('completed',
                      'cancelled_by_client',
                      'cancelled_by_provider',
                      'refunded') then
    raise exception 'Chat indisponível para o status atual do serviço: %', v_job_status
      using errcode = 'P0001';
  end if;

  -- Qualquer outro status (accepted, on_the_way, in_progress, dispute, etc.)
  -- passa direto e o INSERT continua.
end;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_audit_log_message_sent()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.audit_logs(
    entity,
    entity_id,
    action,
    payload,
    performed_by
  )
  values (
    'conversation',            -- tipo de entidade
    NEW.conversation_id,       -- conversa associada à mensagem
    'message_sent',            -- action para envio de mensagem
    jsonb_build_object(
      'message_id', NEW.id,
      'conversation_id', NEW.conversation_id,
      'sender_id', NEW.sender_id,
      'created_at', NEW.created_at
    ),
    auth.uid()
  );

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_dispute_mark_contacted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job_id      uuid;
  v_dispute_id  uuid;
  v_is_provider boolean;
begin
  -- Descobre o job ligado à conversa
  select c.job_id
  into v_job_id
  from public.conversations c
  where c.id = NEW.conversation_id;

  if v_job_id is null then
    return NEW;
  end if;

  -- Existe disputa aberta para esse job?
  select d.id
  into v_dispute_id
  from public.disputes d
  where d.job_id = v_job_id
    and d.status = 'open'
  limit 1;

  if v_dispute_id is null then
    return NEW;
  end if;

  -- Verifica se o remetente é o provider do job
  select exists (
    select 1
    from public.jobs j
    join public.providers p on p.id = j.provider_id
    where j.id = v_job_id
      and p.user_id = NEW.sender_id
  )
  into v_is_provider;

  if not v_is_provider then
    return NEW;
  end if;

  -- Atualiza provider_status apenas se ainda não passou de 'contacted'
  update public.disputes d
  set provider_status = 'contacted'
  where d.id = v_dispute_id
    and provider_status in ('pending','viewed');

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_limit_job_candidates()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_count INT;
BEGIN
  SELECT COUNT(*)
    INTO v_count
  FROM public.job_candidates
  WHERE job_id = NEW.job_id;

  IF v_count >= 4 THEN
    RAISE EXCEPTION 'Este job já atingiu o limite de 4 candidaturas.';
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_log_job_cancellations()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Reagir apenas a UPDATE
  IF TG_OP = 'UPDATE' THEN

    -- Logar apenas quando um job ACEITO é cancelado
    IF OLD.status = 'accepted'
       AND NEW.status IN ('cancelled_by_client', 'cancelled_by_provider')
    THEN
      INSERT INTO public.job_rejections (
        job_id,
        provider_id,
        client_id,
        status,
        reason,
        created_at
      )
      VALUES (
        NEW.id,            -- job_id
        NEW.provider_id,   -- provider_id (providers.id)
        NEW.client_id,     -- client_id (clients.id == auth.uid())
        NEW.status,        -- 'cancelled_by_client' / 'cancelled_by_provider'
        NEW.cancel_reason, -- texto que o app salvou no job
        now()
      );
    END IF;

  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_messages_before_insert_validate()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Garante que não vai entrar mensagem totalmente vazia
  IF (NEW.type IS NULL OR NEW.type = 'text') THEN
    IF NEW.content IS NULL OR btrim(NEW.content) = '' THEN
      -- Se também não tiver image_url, bloqueia
      IF NEW.image_url IS NULL OR btrim(NEW.image_url) = '' THEN
        RAISE EXCEPTION 'Mensagem vazia não pode ser enviada.';
      END IF;

      -- Se tiver imagem mas sem texto, ajusta para tipo image
      NEW.type := 'image';
      NEW.content := '[imagem]';
    ELSE
      NEW.type := COALESCE(NEW.type, 'text');
    END IF;
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_messages_prevent_update_delete()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  raise exception 'Messages cannot be updated or deleted.';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.fn_validate_job_status_transition()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Só valida se o status foi alterado
  IF NEW.status IS DISTINCT FROM OLD.status THEN

    -- Regra 1: job só pode ser cancelado se estiver aceito / em andamento
    IF NEW.status IN ('cancelled_by_client', 'cancelled_by_provider') THEN
      IF OLD.status NOT IN ('accepted', 'on_the_way', 'in_progress') THEN
        RAISE EXCEPTION
          'Job só pode ser cancelado quando está aceito ou em andamento (status atual: %).',
          OLD.status;
      END IF;
    END IF;

  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_roles()
 RETURNS TABLE(user_id uuid, has_client boolean, has_provider boolean, default_role text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with me as (
    select auth.uid() as uid
  )
  select
    me.uid as user_id,
    exists(select 1 from public.clients c where c.id = me.uid) as has_client,
    exists(select 1 from public.providers p where p.id = me.uid) as has_provider,
    case
      when exists(select 1 from public.clients c where c.id = me.uid)
       and not exists(select 1 from public.providers p where p.id = me.uid)
        then 'client'
      when not exists(select 1 from public.clients c where c.id = me.uid)
       and exists(select 1 from public.providers p where p.id = me.uid)
        then 'provider'
      when exists(select 1 from public.clients c where c.id = me.uid)
       and exists(select 1 from public.providers p where p.id = me.uid)
        then 'both'
      else null
    end as default_role
  from me;
$function$
;

CREATE OR REPLACE FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_query_trgm$function$
;

CREATE OR REPLACE FUNCTION public.gin_extract_value_trgm(text, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_value_trgm$function$
;

CREATE OR REPLACE FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_consistent$function$
;

CREATE OR REPLACE FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal)
 RETURNS "char"
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_triconsistent$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_compress$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_consistent$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_decompress$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_distance$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_in(cstring)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_in$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_options(internal)
 RETURNS void
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE
AS '$libdir/pg_trgm', $function$gtrgm_options$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_out(gtrgm)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_out$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_penalty$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_picksplit$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_same$function$
;

CREATE OR REPLACE FUNCTION public.gtrgm_union(internal, internal)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_union$function$
;

CREATE OR REPLACE FUNCTION public.handle_new_user_create_client()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.clients (client_id, email)
  values (new.id, new.email)
  on conflict (client_id) do update
    set email = excluded.email;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_profiles_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.http(request http_request)
 RETURNS http_response
 LANGUAGE c
AS '$libdir/http', $function$http_request$function$
;

CREATE OR REPLACE FUNCTION public.http_delete(uri character varying, content character varying, content_type character varying)
 RETURNS http_response
 LANGUAGE sql
AS $function$ SELECT public.http(('DELETE', $1, NULL, $3, $2)::public.http_request) $function$
;

CREATE OR REPLACE FUNCTION public.http_delete(uri character varying)
 RETURNS http_response
 LANGUAGE sql
AS $function$ SELECT public.http(('DELETE', $1, NULL, NULL, NULL)::public.http_request) $function$
;

CREATE OR REPLACE FUNCTION public.http_get(uri character varying, data jsonb)
 RETURNS http_response
 LANGUAGE sql
AS $function$
        SELECT public.http(('GET', $1 || '?' || public.urlencode($2), NULL, NULL, NULL)::public.http_request)
    $function$
;

CREATE OR REPLACE FUNCTION public.http_get(uri character varying)
 RETURNS http_response
 LANGUAGE sql
AS $function$ SELECT public.http(('GET', $1, NULL, NULL, NULL)::public.http_request) $function$
;

CREATE OR REPLACE FUNCTION public.http_head(uri character varying)
 RETURNS http_response
 LANGUAGE sql
AS $function$ SELECT public.http(('HEAD', $1, NULL, NULL, NULL)::public.http_request) $function$
;

CREATE OR REPLACE FUNCTION public.http_header(field character varying, value character varying)
 RETURNS http_header
 LANGUAGE sql
AS $function$ SELECT $1, $2 $function$
;

CREATE OR REPLACE FUNCTION public.http_list_curlopt()
 RETURNS TABLE(curlopt text, value text)
 LANGUAGE c
AS '$libdir/http', $function$http_list_curlopt$function$
;

CREATE OR REPLACE FUNCTION public.http_patch(uri character varying, content character varying, content_type character varying)
 RETURNS http_response
 LANGUAGE sql
AS $function$ SELECT public.http(('PATCH', $1, NULL, $3, $2)::public.http_request) $function$
;

CREATE OR REPLACE FUNCTION public.http_post(uri character varying, content character varying, content_type character varying)
 RETURNS http_response
 LANGUAGE sql
AS $function$ SELECT public.http(('POST', $1, NULL, $3, $2)::public.http_request) $function$
;

CREATE OR REPLACE FUNCTION public.http_post(uri character varying, data jsonb)
 RETURNS http_response
 LANGUAGE sql
AS $function$
        SELECT public.http(('POST', $1, NULL, 'application/x-www-form-urlencoded', public.urlencode($2))::public.http_request)
    $function$
;

CREATE OR REPLACE FUNCTION public.http_put(uri character varying, content character varying, content_type character varying)
 RETURNS http_response
 LANGUAGE sql
AS $function$ SELECT public.http(('PUT', $1, NULL, $3, $2)::public.http_request) $function$
;

CREATE OR REPLACE FUNCTION public.http_reset_curlopt()
 RETURNS boolean
 LANGUAGE c
AS '$libdir/http', $function$http_reset_curlopt$function$
;

CREATE OR REPLACE FUNCTION public.http_set_curlopt(curlopt character varying, value character varying)
 RETURNS boolean
 LANGUAGE c
AS '$libdir/http', $function$http_set_curlopt$function$
;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    ((auth.jwt() -> 'app_metadata' ->> 'is_admin')::boolean),
    ((auth.jwt() -> 'user_metadata' ->> 'is_admin')::boolean),
    exists(select 1 from public.admin_users au where au.user_id = auth.uid()),
    false
  );
$function$
;

CREATE OR REPLACE FUNCTION public.log_job_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  -- só registra se o status realmente mudou
  if new.status is distinct from old.status then
    insert into public.job_status_history (
      id,
      job_id,
      old_status,
      new_status,
      changed_by,
      changed_at
    ) values (
      gen_random_uuid(),
      new.id,
      old.status,
      new.status,
      auth.uid(),
      now()
    );
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_dispute_contacted(p_dispute_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  update public.disputes d
  set provider_status = 'contacted'
  where d.id = p_dispute_id
    and provider_status in ('pending','viewed')
    and exists (
      select 1
      from public.jobs j
      join public.providers p on p.id = j.provider_id
      where j.id = d.job_id
        and p.user_id = v_user_id
    );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_dispute_solved(p_dispute_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  update public.disputes d
  set provider_status = 'solved'
  where d.id = p_dispute_id
    and exists (
      select 1
      from public.jobs j
      join public.providers p on p.id = j.provider_id
      where j.id = d.job_id
        and p.user_id = v_user_id
    );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_dispute_viewed(p_dispute_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  -- Garante que o usuário é o provider daquele job
  update public.disputes d
  set provider_status    = 'viewed',
      provider_viewed_at = coalesce(provider_viewed_at, now())
  where d.id = p_dispute_id
    and provider_status is distinct from 'solved'
    and exists (
      select 1
      from public.jobs j
      join public.providers p on p.id = j.provider_id
      where j.id = d.job_id
        and p.user_id = v_user_id
    );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_booking_accepted()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO notifications(user_id, title, body, data, created_at, channel)
  VALUES (
    (SELECT user_id FROM providers WHERE id = NEW.provider_id),
    'Novo pedido recebido',
    'Você recebeu um novo pedido: booking ' || NEW.id || '.',
    jsonb_build_object('booking_id', NEW.id, 'event', 'booking_accepted'),
    now(),
    'in_app'
  );
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_chat_message()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  conv record;
  target_user uuid;
begin
  -- pega cliente e prestador da conversa
  select client_id, provider_id
  into conv
  from public.conversations
  where id = new.conversation_id;

  if new.sender_id = conv.client_id then
    target_user := conv.provider_id;
  else
    target_user := conv.client_id;
  end if;

  perform public.send_push_notification(
    p_user_id := target_user,
    p_title   := 'Nova mensagem',
    p_body    := new.content,
    p_data    := jsonb_build_object(
      'type',            'chat_message',
      'conversation_id', new.conversation_id,
      'job_id',          new.job_id
    )
  );

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_client_chat_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  conv record;
  client_user_id uuid;
  preview text;
begin
  -- Só notifica quando quem envia é o PRESTADOR
  if NEW.sender_role <> 'provider' then
    return NEW;
  end if;

  -- Busca dados da conversa (client_id + job_id)
  select c.client_id, c.job_id
    into conv
  from conversations c
  where c.id = NEW.conversation_id;

  -- Se não tiver client_id, não há pra quem notificar
  if conv.client_id is null then
    return NEW;
  end if;

  -- Aqui usamos diretamente o client_id da conversa como user_id
  client_user_id := conv.client_id;

  -- preview da mensagem
  preview := coalesce(NEW.content, '');
  if length(preview) > 120 then
    preview := substring(preview from 1 for 117) || '...';
  end if;

  insert into notifications (
    user_id,
    title,
    body,
    data,
    channel,
    read
  )
  values (
    client_user_id,
    'Nova mensagem do prestador',
    preview,
    jsonb_build_object(
      'type', 'chat_message',
      'conversation_id', NEW.conversation_id,
      'job_id', conv.job_id,
      'from_role', NEW.sender_role
    ),
    'app',
    false
  );

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_client_job_status()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  job_row        record;
  client_user_id uuid;
  title_text     text;
  body_text      text;
begin
  -- Busca o job completo
  select *
    into job_row
  from jobs j
  where j.id = NEW.id;

  if job_row.client_id is null then
    return NEW;
  end if;

  -- Aqui também usamos directamente o client_id como user_id
  client_user_id := job_row.client_id;

  -- Monta título e mensagem conforme o novo status
  if NEW.status = 'on_the_way' then
    title_text := 'Prestador a caminho';
    body_text := format(
      'O prestador está a caminho para o serviço %s.',
      coalesce(NEW.title, job_row.title, 'sem título')
    );

  elsif NEW.status = 'in_progress' then
    title_text := 'Serviço iniciado';
    body_text := format(
      'O prestador iniciou o serviço %s.',
      coalesce(NEW.title, job_row.title, 'sem título')
    );

  elsif NEW.status = 'completed' then
    title_text := 'Serviço finalizado';
    body_text := format(
      'O prestador marcou o serviço %s como concluído.',
      coalesce(NEW.title, job_row.title, 'sem título')
    );

  elsif NEW.status in ('cancelled', 'cancelled_by_provider') then
    title_text := 'Serviço cancelado';
    body_text := format(
      'O prestador cancelou o serviço %s.',
      coalesce(NEW.title, job_row.title, 'sem título')
    );

  elsif NEW.status = 'cancelled_by_client' then
    -- em geral essa notificação iria para o prestador,
    -- mas se você já usa outra function pra isso,
    -- pode simplesmente dar return NEW aqui.
    title_text := 'Você cancelou o serviço';
    body_text := format(
      'O serviço %s foi cancelado.',
      coalesce(NEW.title, job_row.title, 'sem título')
    );

  else
    -- status que não queremos notificar
    return NEW;
  end if;

  insert into notifications (
    user_id,
    title,
    body,
    data,
    channel,
    read
  )
  values (
    client_user_id,
    title_text,
    body_text,
    jsonb_build_object(
      'type',   'job_status',
      'job_id', job_row.id,
      'status', NEW.status
    ),
    'app',
    false
  );

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_client_new_candidate()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_job record;
begin
  -- Busca os dados do job ligado ao candidato
  select j.id, j.client_id, j.title
  into v_job
  from public.jobs j
  where j.id = new.job_id;

  -- Se não tiver client_id, não faz nada
  if v_job.client_id is null then
    return new;
  end if;

  -- Cria notificação para o cliente
  insert into public.notifications (
    user_id,
    title,
    body,
    data,
    channel
  )
  values (
    v_job.client_id,
    'Novo prestador interessado',
    format('Um prestador se candidatou ao serviço %s.', coalesce(v_job.title, '')),
    jsonb_build_object(
      'type', 'new_candidate',
      'job_id', v_job.id,
      'job_title', v_job.title
    ),
    'app'
  );

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_dispute_opened()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_job public.jobs;
begin
  select * into v_job
  from public.jobs
  where id = new.job_id;

  -- Quando cliente abre reclamação, avisa o prestador
  if new.role = 'client' and v_job.provider_id is not null then
    insert into public.notifications (
      user_id, type, title, body, data
    ) values (
      v_job.provider_id,
      'dispute_opened',
      'Um cliente abriu uma reclamação',
      'Entre em contato com o cliente em até 48 horas para tentar resolver o problema.',
      jsonb_build_object(
        'job_id', v_job.id,
        'job_title', v_job.title,
        'dispute_id', new.id
      )
    );
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_job_approved()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  -- Quando o status mudar para 'accepted', cria notificação para o prestador
  if NEW.status = 'accepted'
     and (OLD.status is distinct from NEW.status) then

    insert into public.notifications (user_id, title, body, data, channel, read)
    select p.user_id,
           'Pedido aprovado',
           'O cliente aprovou o pedido ' || coalesce(NEW.title, ''),
           jsonb_build_object('job_id', NEW.id),
           'app',
           false
    from public.providers p
    where p.id = NEW.provider_id;

  end if;

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_job_cancelled()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_who text;
  v_msg text;
begin
  -- Só quando mudou para cancelled
  if NEW.status = 'cancelled'
     and (OLD.status is distinct from NEW.status) then

    v_who := coalesce(NEW.cancelled_by::text, NEW.cancellation_source::text);

    if v_who = 'client' then
      v_msg := 'O cliente cancelou o pedido ' || coalesce(NEW.title, '');
    elsif v_who = 'provider' then
      v_msg := 'Você cancelou o pedido ' || coalesce(NEW.title, '');
    else
      v_msg := 'O pedido ' || coalesce(NEW.title, '') || ' foi cancelado.';
    end if;

    insert into public.notifications (user_id, title, body, data, channel, read)
    select p.user_id,
           'Pedido cancelado',
           v_msg,
           jsonb_build_object(
             'job_id', NEW.id,
             'event', 'cancelled'
           ),
           'app',
           false
    from public.providers p
    where p.id = NEW.provider_id;
  end if;

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_job_candidates_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job record;
  v_cand_count int;
begin
  -- Busca o job
  select j.id, j.client_id, j.status
  into v_job
  from public.jobs j
  where j.id = new.job_id;

  if v_job.id is null then
    return new;
  end if;

  -- Só interessa se ainda estiver aguardando profissionais
  if v_job.status <> 'waiting_providers' then
    return new;
  end if;

  if v_job.client_id is null then
    return new;
  end if;

  -- Conta candidatos atuais
  select count(*) into v_cand_count
  from public.job_candidates c
  where c.job_id = new.job_id;

  -- Regra: dispara quando chegar em 4 ou mais
  if v_cand_count < 4 then
    return new;
  end if;

  -- Já existe notificação desse tipo pra esse job?
  if exists (
    select 1
    from public.notifications n
    where n.user_id = v_job.client_id
      and n.type = 'job_candidates_limit'
      and n.data ->> 'job_id' = new.job_id::text
  ) then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    v_job.client_id,
    'job_candidates_limit',
    'Seu pedido recebeu vários orçamentos',
    'Seu serviço já recebeu ' || v_cand_count ||
      ' propostas. Veja os detalhes e escolha o melhor profissional.',
    jsonb_build_object(
      'job_id', new.job_id,
      'candidate_count', v_cand_count
    )
  );

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_job_completed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if NEW.status = 'completed'
     and (OLD.status is distinct from NEW.status) then

    insert into public.notifications (user_id, title, body, data, channel, read)
    select p.user_id,
           'Serviço finalizado',
           'O serviço ' || coalesce(NEW.title, '') || ' foi marcado como concluído.',
           jsonb_build_object(
             'job_id', NEW.id,
             'event', 'completed'
           ),
           'app',
           false
    from public.providers p
    where p.id = NEW.provider_id;
  end if;

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_job_status()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  title_text text;
  body_text  text;
  data_json  jsonb;
begin
  if new.status = old.status then
    return new;
  end if;

  if new.status = 'accepted' then
    title_text := 'Pedido aprovado';
    body_text  := 'O cliente aprovou o pedido ' || coalesce(new.title, 'Orçamento') || '.';
  elsif new.status = 'completed' then
    title_text := 'Serviço finalizado';
    body_text  := 'O serviço ' || coalesce(new.title, 'Orçamento') || ' foi marcado como concluído.';
  else
    return new; -- não notifica outros status
  end if;

  data_json := jsonb_build_object(
    'type',   'job_status',
    'job_id', new.id,
    'status', new.status
  );

  perform public.send_push_notification(
    p_user_id := new.client_id,
    p_title   := title_text,
    p_body    := body_text,
    p_data    := data_json
  );

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_job_status_change()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_client_id uuid;
  v_provider_user_id uuid;
  v_title_client text;
  v_body_client text;
  v_title_provider text;
  v_body_provider text;
begin
  -- só age se o status realmente mudou
  if new.status is not distinct from old.status then
    return new;
  end if;

  -- pega cliente dono do job
  select j.client_id
  into v_client_id
  from public.jobs j
  where j.id = new.id;

  -- pega user_id do prestador (se houver provider_id)
  if new.provider_id is not null then
    select p.user_id
    into v_provider_user_id
    from public.providers p
    where p.id = new.provider_id;
  end if;

  -- mensagens simples; você pode personalizar depois
  v_title_client := 'Status do seu serviço foi atualizado';
  v_body_client  := format('O status do seu serviço agora é: %s', new.status);

  v_title_provider := 'Status do serviço foi atualizado';
  v_body_provider  := format('O status do serviço agora é: %s', new.status);

  -- notifica cliente
  if v_client_id is not null then
    perform public.create_notification(
      v_client_id,
      v_title_client,
      v_body_client,
      'app',
      jsonb_build_object('job_id', new.id, 'new_status', new.status)
    );
  end if;

  -- notifica prestador, se existir
  if v_provider_user_id is not null then
    perform public.create_notification(
      v_provider_user_id,
      v_title_provider,
      v_body_provider,
      'app',
      jsonb_build_object('job_id', new.id, 'new_status', new.status)
    );
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_job_status_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  job_title text;
  notif_title text;
  notif_body  text;
begin
  -- Só notifica se o status realmente mudou
  if NEW.status is not distinct from OLD.status then
    return NEW;
  end if;

  job_title := coalesce(NEW.title, 'Serviço');

  -- monta título / corpo para o PRESTADOR
  notif_title := case NEW.status
    when 'accepted'            then 'Pedido aprovado'
    when 'on_the_way'          then 'Serviço a caminho'
    when 'in_progress'         then 'Serviço iniciado'
    when 'completed'           then 'Serviço finalizado'
    when 'cancelled_by_client' then 'Pedido cancelado pelo cliente'
    when 'cancelled_by_provider' then 'Pedido cancelado por você'
    else 'Atualização no serviço'
  end;

  notif_body := case NEW.status
    when 'accepted'
      then format('O cliente aprovou o pedido %s.', job_title)
    when 'on_the_way'
      then format('Você marcou o serviço %s como "a caminho".', job_title)
    when 'in_progress'
      then format('Você marcou o serviço %s como "iniciado".', job_title)
    when 'completed'
      then format('Você finalizou o serviço %s.', job_title)
    when 'cancelled_by_client'
      then format('O cliente cancelou o serviço %s.', job_title)
    when 'cancelled_by_provider'
      then format('Você cancelou o serviço %s.', job_title)
    else
      format('Status do serviço %s foi atualizado para %s.', job_title, NEW.status)
  end;

  -- se não tiver provider_id, nem tenta notificar
  if NEW.provider_id is not null then
    insert into public.notifications (
      user_id,
      title,
      body,
      data,
      channel,
      read
    ) values (
      NEW.provider_id,
      notif_title,
      notif_body,
      jsonb_build_object(
        'type',   'job_status',
        'job_id', NEW.id,
        'status', NEW.status
      ),
      'app',
      false
    );
  end if;

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_new_candidate()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_client_id uuid;
  v_title text;
  v_body text;
begin
  -- pega o cliente dono do job
  select j.client_id
  into v_client_id
  from public.jobs j
  where j.id = new.job_id;

  if v_client_id is null then
    return new;
  end if;

  v_title := 'Você recebeu um novo orçamento';
  v_body  := 'Um prestador enviou uma proposta para o seu serviço.';

  perform public.create_notification(
    v_client_id,
    v_title,
    v_body,
    'app',
    jsonb_build_object(
      'job_id', new.job_id,
      'job_candidate_id', new.id
    )
  );

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_new_chat_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  conv record;
  preview text;
begin
  -- só notifica quando quem envia é o cliente
  if NEW.sender_role <> 'client' then
    return NEW;
  end if;

  -- pega dados da conversa (para descobrir o provider)
  select c.provider_id, c.client_id, c.job_id
    into conv
  from conversations c
  where c.id = NEW.conversation_id;

  -- se não achar conversa ou provider, não notifica
  if conv.provider_id is null then
    return NEW;
  end if;

  -- geramos um "preview" curto da mensagem
  preview := coalesce(NEW.content, '');
  if length(preview) > 120 then
    preview := substring(preview from 1 for 117) || '...';
  end if;

  -- insere notificação para o prestador
  insert into notifications (
    user_id,
    title,
    body,
    data,
    channel,
    read
  )
  values (
    conv.provider_id,
    'Nova mensagem do cliente',
    preview,
    jsonb_build_object(
      'type', 'chat_message',
      'conversation_id', NEW.conversation_id,
      'job_id', conv.job_id,
      'from_role', NEW.sender_role
    ),
    'app',
    false
  );

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_new_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  conv         record;
  receiver_id  uuid;
  notif_title  text;
  notif_body   text;
  snippet      text;
begin
  -- Só interessa em INSERT
  if TG_OP <> 'INSERT' then
    return NEW;
  end if;

  -- Busca a conversa para descobrir quem é cliente / prestador
  select *
    into conv
  from public.conversations c
  where c.id = NEW.conversation_id;

  if conv is null then
    return NEW;
  end if;

  -- Decide para quem enviar e o título
  if NEW.sender_id = conv.client_id then
    receiver_id := conv.provider_id;
    notif_title := 'Nova mensagem do cliente';
  else
    receiver_id := conv.client_id;
    notif_title := 'Nova mensagem do prestador';
  end if;

  if receiver_id is null then
    return NEW;
  end if;

  -- Monta um “preview” da mensagem
  snippet := coalesce(NEW.content, '');
  if length(snippet) > 80 then
    snippet := substring(snippet from 1 for 80) || '...';
  end if;

  notif_body := snippet;

  insert into public.notifications (
    user_id,
    title,
    body,
    data,
    channel,
    read
  ) values (
    receiver_id,
    notif_title,
    notif_body,
    jsonb_build_object(
      'type',            'chat_message',
      'conversation_id', NEW.conversation_id,
      'job_id',          conv.job_id
    ),
    'app',
    false
  );

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_new_notification()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- função legacy desativada: não faz mais chamadas HTTP
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_payment_succeeded()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE prov_user uuid;
DECLARE client_user uuid;
BEGIN
  SELECT client_id INTO client_user FROM bookings WHERE id = NEW.booking_id;

  INSERT INTO notifications(user_id, title, body, data, created_at, channel)
  VALUES (
    client_user,
    'Pagamento confirmado',
    'Seu pagamento para o serviço foi confirmado.',
    jsonb_build_object('payment_id', NEW.id, 'booking_id', NEW.booking_id),
    now(),
    'in_app'
  );

  SELECT user_id INTO prov_user FROM providers WHERE id = (SELECT provider_id FROM bookings WHERE id = NEW.booking_id);
  IF prov_user IS NOT NULL THEN
    INSERT INTO notifications(user_id, title, body, data, created_at, channel)
    VALUES (
      prov_user,
      'Pagamento recebido (pendente)',
      'Existe um pagamento pendente ligado ao booking ' || NEW.booking_id || '.',
      jsonb_build_object('payment_id', NEW.id, 'booking_id', NEW.booking_id),
      now(),
      'in_app'
    );
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.onboarding_status_rank(p_status text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case p_status
    when 'started' then 1
    when 'signup_submitted' then 2
    when 'email_confirmed' then 3
    when 'step2_started' then 4
    when 'completed' then 5
    else 0
  end;
$function$
;

CREATE OR REPLACE FUNCTION public.open_job_dispute(p_job_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
declare
  v_job public.jobs%rowtype;
begin
  -- 1) Busca job
  select *
  into v_job
  from public.jobs
  where id = p_job_id;

  if v_job.id is null then
    raise exception 'Job % não encontrado', p_job_id;
  end if;

  -- 2) Só o CLIENTE pode abrir disputa
  if v_job.client_id is distinct from auth.uid() then
    raise exception 'Somente o cliente pode abrir disputa para este serviço.';
  end if;

  -- 3) Só serviços CONCLUÍDOS podem virar disputa
  if v_job.status <> 'completed' then
    raise exception 'Disputa só pode ser aberta para serviços concluídos.';
  end if;

  -- 4) Se já tiver disputa aberta, apenas retorna
  if coalesce(v_job.dispute_open, false) then
    return v_job;
  end if;

  -- 5) Atualiza job -> disputa aberta
  update public.jobs
  set dispute_open      = true,
      dispute_opened_by = auth.uid(),
      dispute_opened_at = now(),
      dispute_reason    = coalesce(p_reason, dispute_reason)
  where id = p_job_id
  returning * into v_job;

  -- 6) Marca conversas do job como 'dispute' (opcional, mas útil pra UI)
  update public.conversations c
  set status = 'dispute'
  where c.job_id = p_job_id;

  -- 7) Loga em audit_logs
  insert into public.audit_logs (
    entity,
    entity_id,
    action,
    payload,
    performed_by,
    created_at
  )
  values (
    'job',
    v_job.id,
    'dispute_opened',
    jsonb_build_object('reason', p_reason),
    auth.uid(),
    now()
  );

  return v_job;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.payments_after_update_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.status = 'succeeded' AND OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM process_payment(NEW.id);
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.payments_apply_split()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_total numeric;
  v_platform numeric;
begin
  v_total := new.amount_total;

  if v_total is null or v_total <= 0 then
    raise exception 'amount_total must be > 0';
  end if;

  v_platform := round(v_total * 0.15, 2);
  new.amount_platform := v_platform;
  new.amount_provider := v_total - v_platform;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.payments_block_amount_change_when_paid()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if old.status = 'paid' then
    if (new.amount_total is distinct from old.amount_total)
       or (new.amount_platform is distinct from old.amount_platform)
       or (new.amount_provider is distinct from old.amount_provider)
       or (new.quote_id is distinct from old.quote_id) then
      raise exception 'Cannot change amounts/quote_id after payment is paid';
    end if;
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.payments_validate_quote_belongs_to_job()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_quote_job uuid;
begin
  if new.quote_id is null then
    return new;
  end if;

  select jq.job_id into v_quote_job
  from public.job_quotes jq
  where jq.id = new.quote_id;

  if v_quote_job is null then
    raise exception 'Invalid quote_id: not found';
  end if;

  if new.job_id is null then
    raise exception 'job_id is required when quote_id is provided';
  end if;

  if v_quote_job <> new.job_id then
    raise exception 'quote_id does not belong to job_id';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.prevent_dual_role_by_id()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if tg_table_name = 'clients' then
    if exists (select 1 from public.providers p where p.user_id = new.id) then
      raise exception 'User already registered as provider';
    end if;
  end if;

  if tg_table_name = 'providers' then
    if exists (select 1 from public.clients c where c.id = new.user_id) then
      raise exception 'User already registered as client';
    end if;
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_expired_disputes()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_dispute record;
  v_job public.jobs;
begin
  for v_dispute in
    select *
    from public.disputes
    where status = 'open'
      and response_deadline_at < now()
  loop
    select * into v_job
    from public.jobs
    where id = v_dispute.job_id;

    -- 1) Marca disputa como auto_refunded
    update public.disputes
    set status = 'auto_refunded',
        auto_refunded_at = now()
    where id = v_dispute.id;

    -- 2) Marca pagamento para estorno (se existir)
    update public.payments
    set status = 'refund_pending'
    where job_id = v_dispute.job_id
      and status = 'paid';

    -- 3) Notificar cliente
    if v_job.client_id is not null then
      insert into public.notifications (
        user_id, type, title, body, data
      ) values (
        v_job.client_id,
        'dispute_auto_refunded',
        'Estorno em andamento',
        'Como não houve retorno do prestador em até 48 horas, o estorno está sendo processado.',
        jsonb_build_object(
          'job_id', v_job.id,
          'job_title', v_job.title,
          'dispute_id', v_dispute.id
        )
      );
    end if;

    -- 4) Notificar prestador
    if v_job.provider_id is not null then
      insert into public.notifications (
        user_id, type, title, body, data
      ) values (
        v_job.provider_id,
        'dispute_auto_refunded',
        'Reclamação não respondida',
        'Você não respondeu à reclamação em 48 horas. O valor será estornado ao cliente.',
        jsonb_build_object(
          'job_id', v_job.id,
          'job_title', v_job.title,
          'dispute_id', v_dispute.id
        )
      );
    end if;

    -- 5) Log em job_actions
    insert into public.job_actions (
      job_id, action, by_user_id, metadata
    ) values (
      v_dispute.job_id,
      'dispute_auto_refunded',
      null,
      jsonb_build_object('dispute_id', v_dispute.id)
    );
  end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_payment(payment_uuid uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  p RECORD;
  b RECORD;
  commission_amt numeric(12,2);
  provider_amt numeric(12,2);
  prov_user uuid;
BEGIN
  SELECT * INTO p FROM payments WHERE id = payment_uuid;
  IF NOT FOUND THEN
    RAISE NOTICE 'Payment % not found', payment_uuid;
    RETURN;
  END IF;

  IF p.status != 'succeeded' THEN
    RAISE NOTICE 'Payment % status is %, aborting', payment_uuid, p.status;
    RETURN;
  END IF;

  SELECT * INTO b FROM bookings WHERE id = p.booking_id;
  IF NOT FOUND THEN
    RAISE NOTICE 'Booking % not found', p.booking_id;
    RETURN;
  END IF;

  commission_amt :=
    round(
      (coalesce(b.total_amount, p.amount) * coalesce(b.commission_percent, 15.0) / 100.0)::numeric,
      2
    );

  provider_amt :=
    round(
      coalesce(p.amount, b.total_amount) - commission_amt,
      2
    );

  UPDATE bookings
  SET
    payment_id = p.id,
    commission_amount = commission_amt,
    amount_provider = provider_amt, -- ✅ corrigido
    status = 'paid',
    updated_at = now()
  WHERE id = b.id;

  IF b.provider_id IS NOT NULL THEN
    INSERT INTO wallets(user_id, balance, pending_balance, created_at, updated_at)
    VALUES (
      (SELECT user_id FROM providers WHERE id = b.provider_id LIMIT 1),
      0,
      0,
      now(),
      now()
    )
    ON CONFLICT (user_id) DO NOTHING;

    SELECT user_id INTO prov_user FROM providers WHERE id = b.provider_id;

    IF prov_user IS NOT NULL THEN
      UPDATE wallets
      SET pending_balance = coalesce(pending_balance,0) + provider_amt,
          updated_at = now()
      WHERE user_id = prov_user;
    END IF;
  END IF;

  INSERT INTO audit_logs(
    entity,
    entity_id,
    action,
    payload,
    performed_by,
    created_at
  )
  VALUES (
    'payment',
    p.id::text,
    'processed',
    jsonb_build_object(
      'payment', to_jsonb(p),
      'commission', commission_amt,
      'amount_provider', provider_amt -- ✅ corrigido
    ),
    NULL,
    now()
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.provider_ensure_profile()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_role public.user_role;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select ur.role into v_role
  from public.user_roles ur
  where ur.user_id = auth.uid();

  if v_role = 'client' then
    raise exception 'Usuário já cadastrado como cliente';
  end if;

  if v_role is null then
    insert into public.user_roles(user_id, role)
    values (auth.uid(), 'provider')
    on conflict (user_id) do nothing;
  end if;

  -- ✅ upsert por user_id (id pode ser gerado, não precisa ser auth.uid)
  insert into public.providers(id, user_id)
  values (gen_random_uuid(), auth.uid())
  on conflict (user_id) do update
    set user_id = excluded.user_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.provider_send_quote(p_job_id uuid, p_approximate_price numeric, p_message text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_provider_id uuid;
  v_quote_id uuid;
  v_candidate_id uuid;
begin
  -- 1) Descobrir provider do usuário logado
  select p.id
    into v_provider_id
  from public.providers p
  where p.user_id = auth.uid()
  limit 1;

  if v_provider_id is null then
    raise exception 'PROVIDER_NOT_FOUND';
  end if;

  if p_approximate_price is null or p_approximate_price <= 0 then
    raise exception 'INVALID_PRICE';
  end if;

  -- 2) Upsert em job_quotes (orçamento)
  insert into public.job_quotes (
    job_id,
    provider_id,
    approximate_price,
    message,
    created_at,
    is_accepted
  )
  values (
    p_job_id,
    v_provider_id,
    p_approximate_price,
    nullif(trim(p_message), ''),
    now(),
    false
  )
  on conflict (job_id, provider_id)
  do update set
    approximate_price = excluded.approximate_price,
    message = excluded.message
  returning id into v_quote_id;

  -- 3) Garantir candidatura em job_candidates
  insert into public.job_candidates (
    job_id,
    provider_id,
    status,
    created_at,
    analyzed,
    approved,
    decision_status,
    client_status
  )
  values (
    p_job_id,
    v_provider_id,
    'candidate',
    now(),
    false,
    false,
    'pending',
    'pending'
  )
  on conflict (job_id, provider_id)
  do update set
    status = 'candidate',
    decision_status = coalesce(public.job_candidates.decision_status, 'pending'),
    client_status = coalesce(public.job_candidates.client_status, 'pending');

  return json_build_object(
    'ok', true,
    'job_id', p_job_id,
    'provider_id', v_provider_id,
    'quote_id', v_quote_id
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.provider_set_job_status(p_job_id uuid, p_new_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job record;
  v_allowed boolean := false;
begin
  -- Carrega o job e valida que existe
  select id, provider_id, status
    into v_job
  from public.jobs
  where id = p_job_id;

  if v_job.id is null then
    raise exception 'Job não encontrado';
  end if;

  -- Só o provider do job pode mudar status
  if v_job.provider_id is null or v_job.provider_id <> auth.uid() then
    raise exception 'Sem permissão: job não pertence a este provider';
  end if;

  -- Status bloqueados
  if v_job.status in ('cancelled','dispute') then
    raise exception 'Job bloqueado para mudança de status (%).', v_job.status;
  end if;

  -- Valida transição (máquina de estados)
  v_allowed :=
    (v_job.status = 'accepted'   and p_new_status = 'on_the_way') or
    (v_job.status = 'on_the_way' and p_new_status = 'in_progress') or
    (v_job.status = 'in_progress' and p_new_status = 'completed');

  if not v_allowed then
    raise exception 'Transição inválida: % -> %', v_job.status, p_new_status;
  end if;

  -- Aplica mudança
  update public.jobs
  set status = p_new_status,
      updated_at = now()
  where id = p_job_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.provider_update_job_status(p_job_id uuid, p_new_status text, p_note text DEFAULT NULL::text)
 RETURNS jobs
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job public.jobs;
  v_uid uuid;
  v_old_status text;
  v_new_status text;

  v_eta int;
  v_avg_kmh numeric := 35;
  v_fallback_eta int := 15;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  v_new_status := trim(coalesce(p_new_status, ''));

  if v_new_status not in ('on_the_way','in_progress','completed','cancelled') then
    raise exception 'invalid_status: %', v_new_status using errcode = '22023';
  end if;

  select * into v_job
  from public.jobs
  where id = p_job_id
  for update;

  if not found then
    raise exception 'job_not_found' using errcode = 'P0002';
  end if;

  if v_job.provider_id is null then
    raise exception 'job_has_no_provider' using errcode = '22023';
  end if;

  if v_job.provider_id <> v_uid then
    raise exception 'not_owner' using errcode = '42501';
  end if;

  v_old_status := trim(coalesce(v_job.status, ''));

  if v_old_status in ('completed','cancelled') then
    raise exception 'status_is_locked' using errcode = '22023';
  end if;

  if v_new_status = v_old_status then
    return v_job;
  end if;

  if v_old_status = 'accepted' then
    if v_new_status not in ('on_the_way','cancelled') then
      raise exception 'invalid_transition: % -> %', v_old_status, v_new_status using errcode = '22023';
    end if;

  elsif v_old_status = 'on_the_way' then
    if v_new_status not in ('in_progress','cancelled') then
      raise exception 'invalid_transition: % -> %', v_old_status, v_new_status using errcode = '22023';
    end if;

  elsif v_old_status = 'in_progress' then
    if v_new_status not in ('completed','cancelled') then
      raise exception 'invalid_transition: % -> %', v_old_status, v_new_status using errcode = '22023';
    end if;

  else
    raise exception 'unsupported_current_status_for_provider: %', v_old_status using errcode = '22023';
  end if;

  -- calcula ETA quando entrar em on_the_way
  if v_new_status = 'on_the_way' then
    if v_job.distance_km is null or v_job.distance_km <= 0 then
      v_eta := v_fallback_eta;
    else
      v_eta := round((v_job.distance_km / v_avg_kmh) * 60.0);
    end if;

    if v_eta < 2 then v_eta := 2; end if;
    if v_eta > 180 then v_eta := 180; end if;
  end if;

  update public.jobs
  set
    status = v_new_status,
    status_updated_at = now(),
    status_updated_by = v_uid,
    status_note = p_note,
    updated_at = now(),

    on_the_way_at = case
      when v_new_status = 'on_the_way' and on_the_way_at is null then now()
      else on_the_way_at
    end,
    in_progress_at = case
      when v_new_status = 'in_progress' and in_progress_at is null then now()
      else in_progress_at
    end,
    completed_at = case
      when v_new_status = 'completed' and completed_at is null then now()
      else completed_at
    end,
    cancelled_at = case
      when v_new_status = 'cancelled' and cancelled_at is null then now()
      else cancelled_at
    end,

    eta_minutes = case
      when v_new_status = 'on_the_way' then v_eta
      else eta_minutes
    end
  where id = p_job_id
  returning * into v_job;

  return v_job;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.register_device_and_push(p_fcm_token text, p_platform text, p_device_token text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  -- 1) Devices (por user + device_token)
  insert into public.user_devices (
    user_id,
    fcm_token,
    platform,
    device_token,
    created_at,
    updated_at
  )
  values (
    auth.uid(),
    p_fcm_token,
    p_platform,
    p_device_token,
    now(),
    now()
  )
  on conflict (user_id, device_token)
  do update set
    fcm_token = excluded.fcm_token,
    platform  = excluded.platform,
    updated_at = now();

  -- 2) Push token "principal" por user
  insert into public.user_push_tokens (
    user_id,
    token,
    created_at
  )
  values (
    auth.uid(),
    p_fcm_token,
    now()
  )
  on conflict (user_id)
  do update set
    token = excluded.token,
    created_at = now();
end $function$
;

CREATE OR REPLACE FUNCTION public.resolve_dispute(p_job_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job public.jobs%rowtype;
  v_has_open_dispute boolean;
  v_can_manage boolean;
begin
  -- Busca o job
  select *
  into v_job
  from public.jobs
  where id = p_job_id;

  if not found then
    raise exception 'Job não encontrado.';
  end if;

  -- Verifica se quem está chamando é:
  -- - o cliente dono do pedido (client_id = auth.uid())
  -- - ou o provider vinculado ao job
  -- - ou um admin
  v_can_manage := (
      v_job.client_id = auth.uid()
      or exists (
        select 1
        from public.providers p
        where p.id = v_job.provider_id
          and p.user_id = auth.uid()
      )
      or public.is_admin()
  );

  if not v_can_manage then
    raise exception 'Você não tem permissão para resolver esta disputa.';
  end if;

  -- Verifica se há disputa aberta para este job
  select exists(
    select 1
    from public.disputes d
    where d.job_id = p_job_id
      and d.status = 'open'
  ) into v_has_open_dispute;

  if not v_has_open_dispute then
    raise exception 'Nenhuma disputa aberta para este job.';
  end if;

  -- Marca disputa como resolvida
  update public.disputes
  set status = 'resolved',
      resolved_at = now()
  where job_id = p_job_id
    and status = 'open';

  -- Se o job estiver em dispute, volta para completed
  update public.jobs
  set status = 'completed'
  where id = p_job_id
    and status = 'dispute';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.resolve_dispute(_dispute_id uuid, _user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_dispute public.disputes;
  v_job public.jobs;
begin
  select * into v_dispute
  from public.disputes
  where id = _dispute_id;

  if not found then
    raise exception 'DISPUTE_NOT_FOUND';
  end if;

  -- Só quem abriu a disputa pode resolvê-la
  if v_dispute.opened_by_user_id <> _user_id then
    raise exception 'NOT_DISPUTE_OWNER';
  end if;

  if v_dispute.status in ('resolved', 'auto_refunded') then
    return;
  end if;

  update public.disputes
  set status = 'resolved',
      resolved_at = now()
  where id = _dispute_id;

  select * into v_job
  from public.jobs
  where id = v_dispute.job_id;

  -- Log opcional em job_actions
  insert into public.job_actions (
    job_id, action, by_user_id, metadata
  ) values (
    v_dispute.job_id,
    'dispute_resolved',
    _user_id,
    jsonb_build_object('dispute_id', _dispute_id)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.resolve_dispute_for_job(p_job_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.resolve_dispute_for_job_full(
    p_job_id        => p_job_id,
    p_resolution    => 'keep_payment',
    p_refund_amount => null
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.resolve_dispute_for_job_full(p_job_id uuid, p_resolution text, p_refund_amount numeric DEFAULT NULL::numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_dispute public.disputes;
  v_payment public.payments;
  v_job     public.jobs;
  v_provider_user_id uuid;
  v_title text;
  v_body  text;
begin
  -- job
  select *
    into v_job
    from public.jobs
   where id = p_job_id;

  if not found then
    raise exception 'Job não encontrado.';
  end if;

  -- prestador -> user_id
  if v_job.provider_id is not null then
    select user_id
      into v_provider_user_id
      from public.providers
     where id = v_job.provider_id;
  end if;

  -- disputa aberta mais recente
  select *
    into v_dispute
    from public.disputes
   where job_id = p_job_id
     and status = 'open'
   order by created_at desc
   limit 1;

  if not found then
    raise exception 'Nenhuma disputa aberta encontrada para este job.';
  end if;

  -- pagamento (se existir)
  select *
    into v_payment
    from public.payments
   where job_id = p_job_id
     and status in ('paid','partially_refunded')
   order by created_at desc
   limit 1;

  --------------------------------------------------------------------
  -- refund_full
  --------------------------------------------------------------------
  if p_resolution = 'refund_full' then

    if v_payment.id is not null then
      update public.payments
         set status        = 'refunded',
             refund_amount = coalesce(p_refund_amount, amount_total),
             refunded_at   = now()
       where id = v_payment.id;
    end if;

    update public.jobs
       set status         = 'cancelled_after_dispute',
           payment_status = 'refunded',
           is_disputed    = false
     where id = p_job_id;

    -- notificações
    v_title := 'Reembolso aprovado';
    v_body  := format(
      'Sua reclamação sobre o pedido %s foi analisada. O valor pago será estornado.',
      coalesce(v_job.job_code, v_job.id::text)
    );

    perform public.send_notification(
      v_job.client_id,
      v_title,
      v_body,
      'dispute_resolved',
      jsonb_build_object(
        'job_id', p_job_id,
        'dispute_id', v_dispute.id,
        'resolution', p_resolution,
        'refund_amount', coalesce(p_refund_amount, v_payment.amount_total)
      )
    );

    if v_provider_user_id is not null then
      v_title := 'Disputa encerrada com reembolso ao cliente';
      v_body  := format(
        'O pedido %s foi encerrado com reembolso total ao cliente. Você não receberá este pagamento.',
        coalesce(v_job.job_code, v_job.id::text)
      );

      perform public.send_notification(
        v_provider_user_id,
        v_title,
        v_body,
        'dispute_resolved',
        jsonb_build_object(
          'job_id', p_job_id,
          'dispute_id', v_dispute.id,
          'resolution', p_resolution
        )
      );
    end if;

  --------------------------------------------------------------------
  -- refund_partial
  --------------------------------------------------------------------
  elsif p_resolution = 'refund_partial' then

    if p_refund_amount is null or p_refund_amount <= 0 then
      raise exception 'Para refund_partial é obrigatório p_refund_amount > 0';
    end if;

    if v_payment.id is not null then
      update public.payments
         set status        = 'partially_refunded',
             refund_amount = p_refund_amount,
             refunded_at   = now()
       where id = v_payment.id;
    end if;

    update public.jobs
       set payment_status = 'partially_refunded',
           is_disputed    = false
     where id = p_job_id;

    -- cliente
    v_title := 'Reembolso parcial aprovado';
    v_body  := format(
      'Sua reclamação sobre o pedido %s foi analisada. Parte do valor será estornada.',
      coalesce(v_job.job_code, v_job.id::text)
    );

    perform public.send_notification(
      v_job.client_id,
      v_title,
      v_body,
      'dispute_resolved',
      jsonb_build_object(
        'job_id', p_job_id,
        'dispute_id', v_dispute.id,
        'resolution', p_resolution,
        'refund_amount', p_refund_amount
      )
    );

    -- prestador
    if v_provider_user_id is not null then
      v_title := 'Disputa encerrada com reembolso parcial';
      v_body  := format(
        'O pedido %s foi encerrado com reembolso parcial ao cliente.',
        coalesce(v_job.job_code, v_job.id::text)
      );

      perform public.send_notification(
        v_provider_user_id,
        v_title,
        v_body,
        'dispute_resolved',
        jsonb_build_object(
          'job_id', p_job_id,
          'dispute_id', v_dispute.id,
          'resolution', p_resolution,
          'refund_amount', p_refund_amount
        )
      );
    end if;

  --------------------------------------------------------------------
  -- keep_payment
  --------------------------------------------------------------------
  elsif p_resolution = 'keep_payment' then

    update public.jobs
       set status      = 'completed',  -- serviço continua finalizado
           is_disputed = false
     where id = p_job_id;

    -- cliente
    v_title := 'Reclamação encerrada';
    v_body  := format(
      'Sua reclamação sobre o pedido %s foi encerrada. O pagamento foi mantido.',
      coalesce(v_job.job_code, v_job.id::text)
    );

    perform public.send_notification(
      v_job.client_id,
      v_title,
      v_body,
      'dispute_resolved',
      jsonb_build_object(
        'job_id', p_job_id,
        'dispute_id', v_dispute.id,
        'resolution', p_resolution
      )
    );

    -- prestador
    if v_provider_user_id is not null then
      v_title := 'Reclamação encerrada';
      v_body  := format(
        'A disputa do pedido %s foi encerrada. O pagamento foi mantido.',
        coalesce(v_job.job_code, v_job.id::text)
      );

      perform public.send_notification(
        v_provider_user_id,
        v_title,
        v_body,
        'dispute_resolved',
        jsonb_build_object(
          'job_id', p_job_id,
          'dispute_id', v_dispute.id,
          'resolution', p_resolution
        )
      );
    end if;

  else
    raise exception 'p_resolution inválido. Use refund_full, refund_partial ou keep_payment.';
  end if;

  --------------------------------------------------------------------
  -- marca disputa como resolvida
  --------------------------------------------------------------------
  update public.disputes
     set status        = 'resolved',
         resolution    = p_resolution,
         refund_amount = coalesce(p_refund_amount, refund_amount),
         resolved_at   = now()
   where id = v_dispute.id;

end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_client_my_jobs_dashboard()
 RETURNS TABLE(job_id uuid, client_id uuid, title text, description text, status text, created_at timestamp with time zone, job_code text, quotes_count integer, new_candidates_count integer, dispute_status text, dispute_id uuid, dispute_opened_by_user_id uuid, dispute_role text, dispute_description text, dispute_created_at timestamp with time zone, dispute_resolved_at timestamp with time zone, auto_refunded_at timestamp with time zone, refund_amount numeric, resolution text, photos json, provider_id uuid)
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
  select
    j.id as job_id,
    j.client_id,
    j.title,
    j.description,
    j.status,
    j.created_at,
    j.job_code,
    coalesce(q.quotes_count, 0) as quotes_count,
    coalesce(c.candidates_count, 0) as new_candidates_count,
    coalesce(d.dispute_status, ''::text) as dispute_status,
    d.dispute_id,
    d.dispute_opened_by_user_id,
    d.dispute_role,
    d.dispute_description,
    d.dispute_created_at,
    d.dispute_resolved_at,
    d.auto_refunded_at,
    d.refund_amount,
    d.resolution,
    d.photos,
    d.provider_id
  from jobs j
  left join (
    select job_id, count(*)::int as quotes_count
    from job_quotes
    group by job_id
  ) q on q.job_id = j.id
  left join (
    select job_id, count(*)::int as candidates_count
    from job_candidates
    group by job_id
  ) c on c.job_id = j.id
  left join lateral (
    select *
    from v_jobs_with_dispute_status v
    where v.job_id = j.id
    order by v.dispute_created_at desc nulls last
    limit 1
  ) d on true
  where j.client_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_client_step1(p_full_name text, p_phone text, p_avatar_url text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid;
  v_email text;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select email
    into v_email
  from auth.users
  where id = v_uid;

  insert into public.clients (
    id,
    full_name,
    phone,
    avatar_url,
    email,
    profile_completed,
    created_at,
    updated_at
  )
  values (
    v_uid,
    p_full_name,
    p_phone,
    p_avatar_url,
    v_email,
    true,
    now(),
    now()
  )
  on conflict (id) do update
  set
    full_name = excluded.full_name,
    phone = excluded.phone,
    avatar_url = coalesce(excluded.avatar_url, clients.avatar_url),
    email = excluded.email,
    profile_completed = true,
    updated_at = now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_client_step2(p_full_name text, p_phone text, p_city text, p_address_zip_code text, p_address_street text, p_address_number text, p_address_district text, p_address_state text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.clients (
    id, full_name, phone, city,
    address_zip_code, address_street, address_number, address_district, address_state,
    address_completed, updated_at
  )
  values (
    v_uid, p_full_name, p_phone, p_city,
    p_address_zip_code, p_address_street, p_address_number, p_address_district, p_address_state,
    true, now()
  )
  on conflict (id) do update
    set
      full_name = excluded.full_name,
      phone = excluded.phone,
      city = excluded.city,
      address_zip_code = excluded.address_zip_code,
      address_street = excluded.address_street,
      address_number = excluded.address_number,
      address_district = excluded.address_district,
      address_state = excluded.address_state,
      address_completed = true,
      updated_at = now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_client_step2(p_city text, p_address_zip_code text, p_address_street text, p_address_number text, p_address_district text, p_address_state text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.clients (
    id,
    city,
    address_zip_code,
    address_street,
    address_number,
    address_district,
    address_state,
    address_completed,
    updated_at
  )
  values (
    v_uid,
    p_city,
    p_address_zip_code,
    p_address_street,
    p_address_number,
    p_address_district,
    p_address_state,
    true,
    now()
  )
  on conflict (id) do update
    set
      city = excluded.city,
      address_zip_code = excluded.address_zip_code,
      address_street = excluded.address_street,
      address_number = excluded.address_number,
      address_district = excluded.address_district,
      address_state = excluded.address_state,
      address_completed = true,
      updated_at = now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_onboarding_upsert(p_status text DEFAULT NULL::text, p_intended_role text DEFAULT NULL::text, p_utm_source text DEFAULT NULL::text, p_utm_medium text DEFAULT NULL::text, p_utm_campaign text DEFAULT NULL::text, p_referrer text DEFAULT NULL::text, p_platform text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := now();

  v_current_status text;
  v_current_rank int := 0;
  v_new_rank int := null;

  v_effective_status text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- garante linha
  insert into public.user_onboarding(user_id, intended_role, status, started_at, updated_at)
  values (
    v_uid,
    case when p_intended_role in ('client','provider') then p_intended_role else null end,
    coalesce(p_status, 'started'),
    v_now,
    v_now
  )
  on conflict (user_id) do nothing;

  -- status atual
  select u.status into v_current_status
  from public.user_onboarding u
  where u.user_id = v_uid;

  v_current_rank := public.onboarding_status_rank(coalesce(v_current_status, 'started'));
  if p_status is not null then
    v_new_rank := public.onboarding_status_rank(p_status);
  end if;

  -- decide status final (não regride; status inválido ignora)
  v_effective_status :=
    case
      when p_status is null then v_current_status
      when v_new_rank = 0 then v_current_status
      when v_new_rank >= v_current_rank then p_status
      else v_current_status
    end;

  update public.user_onboarding u
  set
    intended_role = coalesce(
      case when p_intended_role in ('client','provider') then p_intended_role else null end,
      u.intended_role
    ),

    utm_source = coalesce(p_utm_source, u.utm_source),
    utm_medium = coalesce(p_utm_medium, u.utm_medium),
    utm_campaign = coalesce(p_utm_campaign, u.utm_campaign),
    referrer = coalesce(p_referrer, u.referrer),
    platform = coalesce(p_platform, u.platform),

    status = coalesce(v_effective_status, u.status),

    signup_submitted_at = case
      when v_effective_status = 'signup_submitted' then coalesce(u.signup_submitted_at, v_now)
      else u.signup_submitted_at
    end,

    email_confirmed_at = case
      when v_effective_status = 'email_confirmed' then coalesce(u.email_confirmed_at, v_now)
      else u.email_confirmed_at
    end,

    step2_started_at = case
      when v_effective_status = 'step2_started' then coalesce(u.step2_started_at, v_now)
      else u.step2_started_at
    end,

    completed_at = case
      when v_effective_status = 'completed' then coalesce(u.completed_at, v_now)
      else u.completed_at
    end,

    updated_at = v_now
  where u.user_id = v_uid;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_provider_mark_phone_verified()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  -- tenta atualizar phone_verified apenas se a coluna existir
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'providers'
      and column_name = 'phone_verified'
  ) then
    update public.providers p
    set phone_verified = true,
        updated_at = now()
    where p.user_id = auth.uid();
  else
    update public.providers p
    set updated_at = now()
    where p.user_id = auth.uid();
  end if;

  if not found then
    raise exception 'Provider não encontrado para este usuário.';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_provider_set_services(p_service_type_ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_provider_id uuid;
  v_count int;
begin
  if p_service_type_ids is null or array_length(p_service_type_ids, 1) is null then
    raise exception 'Selecione pelo menos um serviço.';
  end if;

  -- limite total (MVP)
  v_count := array_length(p_service_type_ids, 1);
  if v_count > 4 then
    raise exception 'Você pode selecionar no máximo 4 serviços.';
  end if;

  select p.id into v_provider_id
  from public.providers p
  where p.user_id = auth.uid()
  limit 1;

  if v_provider_id is null then
    raise exception 'Provider não encontrado para este usuário.';
  end if;

  -- limpa antigos
  delete from public.provider_service_types
  where provider_id = v_provider_id;

  -- insere novos
  insert into public.provider_service_types (provider_id, service_type_id)
  select v_provider_id, x
  from unnest(p_service_type_ids) as x;

  -- marca configurado
  update public.providers
  set has_configured_services = true,
      updated_at = now()
  where id = v_provider_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_provider_set_services(p_full_name text, p_phone text, p_city text, p_cep text, p_address_street text, p_address_number text, p_address_complement text, p_address_district text, p_state text, p_service_type_ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_provider_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if array_length(p_service_type_ids, 1) is null then
    raise exception 'No services selected';
  end if;

  insert into public.providers (
    id, user_id, full_name, phone, city, cep, state,
    address_street, address_number, address_complement, address_district,
    has_configured_services, onboarding_completed, updated_at
  )
  values (
    gen_random_uuid(), v_user_id, p_full_name, p_phone, p_city, p_cep, p_state,
    p_address_street, p_address_number, p_address_complement, p_address_district,
    true, true, now()
  )
  on conflict (user_id) do update
    set
      full_name = excluded.full_name,
      phone = excluded.phone,
      city = excluded.city,
      cep = excluded.cep,
      state = excluded.state,
      address_street = excluded.address_street,
      address_number = excluded.address_number,
      address_complement = excluded.address_complement,
      address_district = excluded.address_district,
      has_configured_services = true,
      onboarding_completed = true,
      updated_at = now()
  returning id into v_provider_id;

  if v_provider_id is null then
    select id into v_provider_id
    from public.providers
    where user_id = v_user_id;
  end if;

  delete from public.provider_service_types
  where provider_id = v_provider_id;

  insert into public.provider_service_types (id, provider_id, service_type_id, created_at)
  select gen_random_uuid(), v_provider_id, unnest(p_service_type_ids), now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_provider_set_services(p_city text, p_cep text, p_address_street text, p_address_number text, p_address_complement text, p_address_district text, p_state text, p_service_type_ids uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_provider_id uuid;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;

  if array_length(p_service_type_ids, 1) is null then
    raise exception 'No services selected';
  end if;

  -- 1) garante provider (por user_id) e pega o providers.id
  insert into public.providers (
    id,
    user_id,
    city,
    cep,
    state,
    address_street,
    address_number,
    address_complement,
    address_district,
    has_configured_services,
    onboarding_completed,
    updated_at
  )
  values (
    gen_random_uuid(),
    v_user_id,
    p_city,
    p_cep,
    p_state,
    p_address_street,
    p_address_number,
    p_address_complement,
    p_address_district,
    true,
    true,
    now()
  )
  on conflict (user_id) do update
    set
      city = excluded.city,
      cep = excluded.cep,
      state = excluded.state,
      address_street = excluded.address_street,
      address_number = excluded.address_number,
      address_complement = excluded.address_complement,
      address_district = excluded.address_district,
      has_configured_services = true,
      onboarding_completed = true,
      updated_at = now()
  returning id into v_provider_id;

  -- fallback extra (caso raro de returning não preencher)
  if v_provider_id is null then
    select id into v_provider_id
    from public.providers
    where user_id = v_user_id;
  end if;

  if v_provider_id is null then
    raise exception 'Could not resolve provider_id';
  end if;

  -- 2) substitui serviços (provider_service_types usa provider_id = providers.id)
  delete from public.provider_service_types
  where provider_id = v_provider_id;

  insert into public.provider_service_types (
    id,
    provider_id,
    service_type_id,
    created_at
  )
  select
    gen_random_uuid(),
    v_provider_id,
    unnest(p_service_type_ids),
    now();

end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_provider_update_address(p_cep text, p_address_street text, p_address_number text, p_address_complement text, p_address_district text, p_city text, p_state text, p_mark_onboarding_completed boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  update public.providers p
  set
    cep = nullif(p_cep, ''),
    address_street = nullif(p_address_street, ''),
    address_number = nullif(p_address_number, ''),
    address_complement = nullif(p_address_complement, ''),
    address_district = nullif(p_address_district, ''),
    city = nullif(p_city, ''),
    state = nullif(upper(p_state), ''),
    onboarding_completed = case
      when p_mark_onboarding_completed then true
      else p.onboarding_completed
    end,
    updated_at = now()
  where p.user_id = auth.uid();

  if not found then
    raise exception 'Provider não encontrado para este usuário.';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_provider_update_avatar(p_avatar_url text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  update public.providers p
  set avatar_url = p_avatar_url,
      updated_at = now()
  where p.user_id = auth.uid();

  if not found then
    raise exception 'Provider não encontrado para este usuário.';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rpc_provider_update_me(p_full_name text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_address_city text DEFAULT NULL::text, p_address_state text DEFAULT NULL::text, p_address_cep text DEFAULT NULL::text, p_address_street text DEFAULT NULL::text, p_address_number text DEFAULT NULL::text, p_address_district text DEFAULT NULL::text, p_address_complement text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID;
  v_provider_id UUID;
  v_result JSON;
BEGIN
  -- 1. Obter ID do usuário autenticado
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- 2. Buscar provider_id
  SELECT id INTO v_provider_id
  FROM providers
  WHERE user_id = v_user_id;

  IF v_provider_id IS NULL THEN
    RAISE EXCEPTION 'Prestador não encontrado';
  END IF;

  -- 3. Validações
  IF p_full_name IS NOT NULL AND LENGTH(TRIM(p_full_name)) < 3 THEN
    RAISE EXCEPTION 'Nome deve ter pelo menos 3 caracteres';
  END IF;

  IF p_phone IS NOT NULL THEN
    -- Remover caracteres não numéricos
    p_phone := REGEXP_REPLACE(p_phone, '[^0-9]', '', 'g');
    
    IF LENGTH(p_phone) < 10 OR LENGTH(p_phone) > 11 THEN
      RAISE EXCEPTION 'Telefone inválido (deve ter 10 ou 11 dígitos)';
    END IF;
  END IF;

  IF p_address_cep IS NOT NULL THEN
    -- Remover caracteres não numéricos
    p_address_cep := REGEXP_REPLACE(p_address_cep, '[^0-9]', '', 'g');
    
    IF LENGTH(p_address_cep) != 8 THEN
      RAISE EXCEPTION 'CEP inválido (deve ter 8 dígitos)';
    END IF;
  END IF;

  -- 4. Atualizar dados
  UPDATE providers
  SET
    full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
    phone = COALESCE(p_phone, phone),
    address_city = COALESCE(NULLIF(TRIM(p_address_city), ''), address_city),
    address_state = COALESCE(NULLIF(TRIM(p_address_state), ''), address_state),
    address_cep = COALESCE(p_address_cep, address_cep),
    address_street = COALESCE(NULLIF(TRIM(p_address_street), ''), address_street),
    address_number = COALESCE(NULLIF(TRIM(p_address_number), ''), address_number),
    address_district = COALESCE(NULLIF(TRIM(p_address_district), ''), address_district),
    address_complement = COALESCE(NULLIF(TRIM(p_address_complement), ''), address_complement),
    updated_at = NOW()
  WHERE id = v_provider_id;

  -- 5. Retornar dados atualizados
  SELECT json_build_object(
    'id', id,
    'user_id', user_id,
    'full_name', full_name,
    'phone', phone,
    'address_city', address_city,
    'address_state', address_state,
    'address_cep', address_cep,
    'updated_at', updated_at
  ) INTO v_result
  FROM providers
  WHERE id = v_provider_id;

  -- 6. Log de auditoria
  INSERT INTO audit_logs (
    entity,
    entity_id,
    action,
    payload,
    performed_by
  ) VALUES (
    'provider',
    v_provider_id::TEXT,
    'update_profile',
    json_build_object(
      'fields_updated', json_build_object(
        'full_name', p_full_name IS NOT NULL,
        'phone', p_phone IS NOT NULL,
        'address', p_address_city IS NOT NULL OR p_address_street IS NOT NULL
      )
    ),
    v_user_id
  );

  RETURN v_result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.search_services(term text, user_lat numeric DEFAULT NULL::numeric, user_lng numeric DEFAULT NULL::numeric, lim integer DEFAULT 30)
 RETURNS TABLE(service_id integer, slug text, name text, description text, base_price numeric, category_id integer, similarity_score numeric, avg_provider_distance_km numeric)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.slug,
    s.name,
    s.description,
    s.base_price,
    s.category_id,
    COALESCE(similarity(s.name, term), 0) as sim_score,
    CASE
      WHEN user_lat IS NULL OR user_lng IS NULL THEN NULL
      ELSE (
        SELECT ROUND(AVG(111.045 * DEGREES(ACOS(
          COS(RADIANS(user_lat)) * COS(RADIANS(p.lat)) * COS(RADIANS(p.lng) - RADIANS(user_lng)) +
          SIN(RADIANS(user_lat)) * SIN(RADIANS(p.lat))
        )) ), 3)
        FROM providers p
        JOIN provider_services ps ON ps.provider_id = p.id
        WHERE ps.service_id = s.id AND ps.active = true AND p.lat IS NOT NULL AND p.lng IS NOT NULL
      )
    END as avg_dist_km
  FROM services_catalog s
  WHERE
    (s.name ILIKE '%' || term || '%'
     OR s.description ILIKE '%' || term || '%'
     OR (s.name % term)
     OR (s.description % term)
    )
  ORDER BY COALESCE(similarity(s.name, term), 0) DESC, avg_dist_km ASC NULLS LAST, s.name
  LIMIT lim;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.send_message(p_conversation_id uuid, p_sender_role text, p_content text, p_type text DEFAULT 'text'::text, p_image_url text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid;
  v_conv conversations%rowtype;
  v_type text;
  v_content text;
  v_image text;
  v_read_by_client boolean := false;
  v_read_by_provider boolean := false;
begin
  -- auth
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  -- normalização
  v_type := coalesce(nullif(trim(p_type), ''), 'text');
  v_content := coalesce(p_content, '');
  v_image := nullif(trim(coalesce(p_image_url, '')), '');

  if p_sender_role not in ('client', 'provider') then
    raise exception 'invalid_sender_role';
  end if;

  -- conversa
  select *
    into v_conv
  from conversations
  where id = p_conversation_id;

  if not found then
    raise exception 'conversation_not_found';
  end if;

  -- valida participação
  if p_sender_role = 'client' then
    if v_conv.client_id <> v_uid then
      raise exception 'not_allowed';
    end if;
    v_read_by_client := true;
  else
    if v_conv.provider_id <> v_uid then
      raise exception 'not_allowed';
    end if;
    v_read_by_provider := true;
  end if;

  -- valida payload
  if v_type = 'text' then
    if length(trim(v_content)) = 0 then
      raise exception 'empty_message';
    end if;
    v_image := null;

  elsif v_type = 'image' then
    if v_image is null then
      raise exception 'image_url_required';
    end if;
    v_content := '';

  else
    raise exception 'invalid_message_type';
  end if;

  -- insert mensagem
  insert into messages (
    conversation_id,
    sender_id,
    sender_role,
    content,
    type,
    image_url,
    sent_at,
    read_by_client,
    read_by_provider
  ) values (
    p_conversation_id,
    v_uid,
    p_sender_role,
    v_content,
    v_type,
    v_image,
    now(),
    v_read_by_client,
    v_read_by_provider
  );

  -- atualiza conversa
  update conversations
     set last_message_at = now(),
         updated_at = now()
   where id = p_conversation_id;

end;
$function$
;

CREATE OR REPLACE FUNCTION public.send_notification(p_user_id uuid, p_title text, p_body text, p_type text, p_data jsonb DEFAULT '{}'::jsonb, p_channel text DEFAULT 'app'::text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  insert into public.notifications (
    user_id,
    title,
    body,
    type,
    data,
    channel,
    read
  )
  values (
    p_user_id,
    p_title,
    p_body,
    p_type,
    coalesce(p_data, '{}'::jsonb),
    coalesce(p_channel, 'app'),
    false
  );
$function$
;

CREATE OR REPLACE FUNCTION public.send_push_notification()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.send_push_notification(p_user_id uuid, p_title text, p_body text, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
declare
  tokens          text[];
  edge_url        text;
  service_role_key text;
  payload         jsonb;
begin
  -- coleta todos os device_tokens do usuário
  select array_agg(ud.device_token)
  into tokens
  from public.user_devices ud
  where ud.user_id = p_user_id
    and ud.device_token is not null;

  if tokens is null or array_length(tokens, 1) = 0 then
    return;
  end if;

  edge_url := current_setting('app.settings.edge_base_url', true);
  service_role_key := current_setting('app.settings.service_role_key', true);

  payload := jsonb_build_object(
    'channel', 'app',
    'title',   p_title,
    'body',    p_body,
    'data',    coalesce(p_data, '{}'::jsonb),
    'tokens',  tokens
  );

  begin
    perform net.http_post(
      url := edge_url || '/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      ),
      body := payload
    );
  exception
    when others then
      raise notice 'send-push error: %', sqlerrm;
  end;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_dispute_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE dh int;
BEGIN
  SELECT dispute_hours INTO dh FROM services_catalog WHERE id = NEW.service_id;
  IF dh IS NULL THEN dh := 48; END IF;
  NEW.dispute_deadline := NEW.scheduled_at + make_interval(hours => dh);
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_job_status_dispute_on_open_dispute()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Só quando a disputa está "open"
  IF NEW.status = 'open' THEN
    -- Atualiza o job (se estava finalizado/cancelado)
    UPDATE public.jobs
       SET status = 'dispute'
     WHERE id = NEW.job_id
       AND status IN (
         'completed',
         'cancelled_by_client',
         'cancelled_by_provider'
       );

    -- Reabre o chat marcando como "dispute" (se estava "closed")
    UPDATE public.conversations
       SET status = 'dispute'
     WHERE job_id = NEW.job_id
       AND status = 'closed';
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_limit(real)
 RETURNS real
 LANGUAGE c
 STRICT
AS '$libdir/pg_trgm', $function$set_limit$function$
;

CREATE OR REPLACE FUNCTION public.set_partner_store_products_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_partner_stores_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_profiles_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Só seta updated_at se o registro tiver esse campo
  IF to_jsonb(NEW) ? 'updated_at' THEN
    NEW.updated_at := now();
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_user_avatar_url(p_role text, p_avatar_url text)
 RETURNS TABLE(role text, avatar_url text, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_role not in ('client', 'provider') then
    raise exception 'Invalid role. Use client or provider.';
  end if;

  if p_avatar_url is null or length(trim(p_avatar_url)) = 0 then
    raise exception 'avatar_url cannot be empty';
  end if;

  if p_role = 'client' then
    update public.clients
       set avatar_url = p_avatar_url,
           updated_at = now()
     where id = v_uid;

    if not found then
      raise exception 'Client profile not found for this user';
    end if;

    return query
    select 'client'::text, c.avatar_url, c.updated_at
      from public.clients c
     where c.id = v_uid;

  else
    update public.providers
       set avatar_url = p_avatar_url,
           updated_at = now()
     where id = v_uid;

    if not found then
      raise exception 'Provider profile not found for this user';
    end if;

    return query
    select 'provider'::text, p.avatar_url, p.updated_at
      from public.providers p
     where p.id = v_uid;
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.show_limit()
 RETURNS real
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_limit$function$
;

CREATE OR REPLACE FUNCTION public.show_trgm(text)
 RETURNS text[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_trgm$function$
;

CREATE OR REPLACE FUNCTION public.similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity$function$
;

CREATE OR REPLACE FUNCTION public.similarity_dist(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_dist$function$
;

CREATE OR REPLACE FUNCTION public.similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_op$function$
;

CREATE OR REPLACE FUNCTION public.strict_word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity$function$
;

CREATE OR REPLACE FUNCTION public.strict_word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_commutator_op$function$
;

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_commutator_op$function$
;

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_op$function$
;

CREATE OR REPLACE FUNCTION public.strict_word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_op$function$
;

CREATE OR REPLACE FUNCTION public.submit_job_quote(p_job_id uuid, p_approximate_price numeric, p_message text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid;
  v_provider_id uuid;
  v_candidate_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  -- pega provider_id do usuário logado
  select id into v_provider_id
  from public.providers
  where user_id = v_user_id
  limit 1;

  if v_provider_id is null then
    raise exception 'provider_not_found';
  end if;

  -- 1) garante candidatura (status permitido pelo CHECK!)
  insert into public.job_candidates (
    job_id,
    provider_id,
    status,
    analyzed,
    approved,
    decision_status,
    client_status
  )
  values (
    p_job_id,
    v_provider_id,
    'pending',
    false,
    false,
    'pending',
    'pending'
  )
  on conflict (job_id, provider_id)
  do update set
    status = 'pending',
    decision_status = 'pending',
    client_status = 'pending';

  -- 2) cria/atualiza quote
  insert into public.job_quotes (
    job_id,
    provider_id,
    approximate_price,
    message,
    is_accepted
  )
  values (
    p_job_id,
    v_provider_id,
    p_approximate_price,
    p_message,
    false
  )
  on conflict (job_id, provider_id)
  do update set
    approximate_price = excluded.approximate_price,
    message = excluded.message,
    is_accepted = false;

  return json_build_object(
    'ok', true,
    'job_id', p_job_id,
    'provider_id', v_provider_id
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_dispute_refund_from_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Só faz algo se for UPDATE
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  -- Condição de "foi reembolsado"
  if (
    new.status in ('refunded', 'chargeback')
    or (coalesce(new.refund_amount, 0) > 0 and new.refunded_at is not null)
  ) then
    update public.disputes d
       set status = 'refunded',
           refund_amount = coalesce(new.refund_amount, d.refund_amount),
           auto_refunded_at = coalesce(new.refunded_at, d.auto_refunded_at),
           resolved_at = coalesce(d.resolved_at, new.refunded_at, now())
     where d.job_id = new.job_id
       and d.status <> 'refunded';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_job_payment_from_payments()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_job public.jobs;
  v_provider_user_id uuid;
  v_title text;
  v_body text;
begin
  -- Se não tiver job associado, não faz nada
  if NEW.job_id is null then
    return NEW;
  end if;

  -- carrega o job
  select *
    into v_job
    from public.jobs
   where id = NEW.job_id;

  if not found then
    return NEW;
  end if;

  -- descobre user_id do prestador (providers.id -> auth.users.id)
  if v_job.provider_id is not null then
    select user_id
      into v_provider_user_id
      from public.providers
     where id = v_job.provider_id;
  end if;

  --------------------------------------------------------------------
  -- STATUS = PAID
  --------------------------------------------------------------------
  if NEW.status = 'paid' then

    update public.jobs
       set payment_status = 'paid',
           paid_at        = coalesce(NEW.paid_at, paid_at, now()),
           price          = coalesce(price, NEW.amount_total),
           updated_at     = now()
     where id = NEW.job_id;

    -- Notificação para o cliente
    v_title := 'Pagamento aprovado';
    v_body  := format(
      'Seu pagamento para o pedido %s foi aprovado.',
      coalesce(v_job.job_code, v_job.id::text)
    );

    perform public.send_notification(
      v_job.client_id,
      v_title,
      v_body,
      'payment_paid',
      jsonb_build_object(
        'job_id', NEW.job_id,
        'payment_id', NEW.id,
        'amount', NEW.amount_total
      )
    );

    -- Notificação para o prestador (se tiver)
    if v_provider_user_id is not null then
      v_title := 'Você tem um serviço com pagamento aprovado';
      v_body  := format(
        'O pagamento do pedido %s foi aprovado. O valor será liberado após o prazo de segurança.',
        coalesce(v_job.job_code, v_job.id::text)
      );

      perform public.send_notification(
        v_provider_user_id,
        v_title,
        v_body,
        'payment_paid',
        jsonb_build_object(
          'job_id', NEW.job_id,
          'payment_id', NEW.id,
          'amount', NEW.amount_total
        )
      );
    end if;

  --------------------------------------------------------------------
  -- STATUS = REFUNDED
  --------------------------------------------------------------------
  elsif NEW.status = 'refunded' then

    update public.jobs
       set payment_status = 'refunded',
           status = case
                      when status = 'dispute' then 'cancelled_after_dispute'
                      else status
                    end,
           updated_at = now()
     where id = NEW.job_id;

    -- Cliente: pagamento estornado
    v_title := 'Pagamento estornado';
    v_body  := format(
      'O pagamento do pedido %s foi estornado. O valor será devolvido de acordo com o prazo da operadora.',
      coalesce(v_job.job_code, v_job.id::text)
    );

    perform public.send_notification(
      v_job.client_id,
      v_title,
      v_body,
      'payment_refunded',
      jsonb_build_object(
        'job_id', NEW.job_id,
        'payment_id', NEW.id,
        'refund_amount', coalesce(NEW.refund_amount, NEW.amount_total)
      )
    );

    -- Prestador: cliente recebeu reembolso
    if v_provider_user_id is not null then
      v_title := 'Pagamento estornado ao cliente';
      v_body  := format(
        'O pedido %s teve o pagamento estornado ao cliente após análise de disputa.',
        coalesce(v_job.job_code, v_job.id::text)
      );

      perform public.send_notification(
        v_provider_user_id,
        v_title,
        v_body,
        'payment_refunded',
        jsonb_build_object(
          'job_id', NEW.job_id,
          'payment_id', NEW.id
        )
      );
    end if;

  --------------------------------------------------------------------
  -- STATUS = PARTIALLY_REFUNDED
  --------------------------------------------------------------------
  elsif NEW.status = 'partially_refunded' then

    update public.jobs
       set payment_status = 'partially_refunded',
           updated_at     = now()
     where id = NEW.job_id;

    -- Cliente: reembolso parcial
    v_title := 'Reembolso parcial aprovado';
    v_body  := format(
      'Uma parte do pagamento do pedido %s foi estornada. Veja os detalhes no histórico do pedido.',
      coalesce(v_job.job_code, v_job.id::text)
    );

    perform public.send_notification(
      v_job.client_id,
      v_title,
      v_body,
      'payment_partial_refund',
      jsonb_build_object(
        'job_id', NEW.job_id,
        'payment_id', NEW.id,
        'refund_amount', NEW.refund_amount
      )
    );

    -- Prestador: reembolso parcial
    if v_provider_user_id is not null then
      v_title := 'Reembolso parcial ao cliente';
      v_body  := format(
        'Uma parte do pagamento do pedido %s foi estornada ao cliente após análise.',
        coalesce(v_job.job_code, v_job.id::text)
      );

      perform public.send_notification(
        v_provider_user_id,
        v_title,
        v_body,
        'payment_partial_refund',
        jsonb_build_object(
          'job_id', NEW.job_id,
          'payment_id', NEW.id,
          'refund_amount', NEW.refund_amount
        )
      );
    end if;

  --------------------------------------------------------------------
  -- STATUS = FAILED
  --------------------------------------------------------------------
  elsif NEW.status = 'failed' then

    update public.jobs
       set payment_status = 'failed',
           updated_at     = now()
     where id = NEW.job_id;

    v_title := 'Pagamento não aprovado';
    v_body  := format(
      'Não foi possível concluir o pagamento do pedido %s. Tente novamente ou use outro método.',
      coalesce(v_job.job_code, v_job.id::text)
    );

    perform public.send_notification(
      v_job.client_id,
      v_title,
      v_body,
      'payment_failed',
      jsonb_build_object(
        'job_id', NEW.job_id,
        'payment_id', NEW.id
      )
    );

  end if;

  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_profile_from_clients()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (
    id, full_name, role, city, avatar_url, rating, bio, is_verified, created_at
  )
  values (
    new.id,
    new.full_name,
    'client',          -- ✅ fixo
    new.city,
    new.avatar_url,
    null,
    null,
    false,
    now()
  )
  on conflict (id)
  do update set
    full_name  = excluded.full_name,
    role       = 'client',
    city       = excluded.city,
    avatar_url = excluded.avatar_url;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_profile_from_providers()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (
    id, full_name, role, city, avatar_url, rating, bio, is_verified, created_at
  )
  values (
    new.user_id,                 -- ✅ auth.uid (não o providers.id)
    new.full_name,
    'provider',                  -- ✅ fixa o papel (sem coluna role)
    new.city,
    new.avatar_url,
    new.rating,
    new.bio,
    new.is_verified,
    coalesce(new.created_at, now())
  )
  on conflict (id)
  do update set
    full_name   = excluded.full_name,
    role        = excluded.role,
    city        = excluded.city,
    avatar_url  = excluded.avatar_url,
    rating      = excluded.rating,
    bio         = excluded.bio,
    is_verified = excluded.is_verified;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.text_to_bytea(data text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/http', $function$text_to_bytea$function$
;

CREATE OR REPLACE FUNCTION public.touch_user_onboarding_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_close_job_dispute()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.status in ('resolved', 'refunded')
     and old.status <> new.status then

    update public.jobs
    set
      status = 'completed',
      dispute_status = new.status
    where id = new.job_id;

  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_disputes_after_insert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- Abriu disputa => job vai para dispute
  update public.jobs
  set status = 'dispute'
  where id = new.job_id;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_disputes_after_update()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- Só reage quando status muda
  if new.status is distinct from old.status then
    if new.status in ('resolved','refunded') then
      update public.jobs
      set
        status = 'completed',
        dispute_status = new.status
      where id = new.job_id;
    end if;
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_disputes_before_insert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_job_status text;
  v_provider_id uuid;
begin
  -- 1) Disputa só nasce como OPEN
  if new.status is null then
    new.status := 'open';
  end if;

  if new.status <> 'open' then
    raise exception 'Disputa deve ser criada com status open';
  end if;

  -- 2) Só pode abrir disputa se job estiver COMPLETED
  select j.status, j.provider_id
    into v_job_status, v_provider_id
  from public.jobs j
  where j.id = new.job_id;

  if v_job_status is null then
    raise exception 'Job não encontrado';
  end if;

  if v_job_status <> 'completed' then
    raise exception 'Disputa só pode ser aberta quando o job estiver completed';
  end if;

  -- 3) Preenche provider_id (se sua tabela disputes tiver essa coluna)
  --    (se não existir, esse trecho vai dar erro; então só use se provider_id já existe)
  if new.provider_id is null then
    new.provider_id := v_provider_id;
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_disputes_limit_provider_update()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_is_provider boolean;
  v_is_opener   boolean;
begin
  -- Libera geral para service_role / postgres / supabase_admin
  if auth.role() = 'service_role'
     or auth.role() = 'supabase_admin'
  then
    return new;
  end if;

  -- Usuário logado é quem abriu a disputa? (cliente)
  v_is_opener := (new.opened_by_user_id = auth.uid());

  -- Usuário logado é o provider do job?
  select exists (
    select 1
    from public.jobs j
    where j.id = new.job_id
      and j.provider_id = auth.uid()
  )
  into v_is_provider;

  -- Se for o provider (e não o cliente que abriu), aplicamos a trava
  if v_is_provider and not v_is_opener then

    -- Campos que o provider NÃO pode mexer:
    if new.id                       is distinct from old.id
       or new.job_id                is distinct from old.job_id
       or new.opened_by_user_id     is distinct from old.opened_by_user_id
       or new.role                  is distinct from old.role
       or new.description           is distinct from old.description
       or new.status                is distinct from old.status
       or new.created_at            is distinct from old.created_at
       or new.response_deadline_at  is distinct from old.response_deadline_at
       or new.resolved_at           is distinct from old.resolved_at
       or new.auto_refunded_at      is distinct from old.auto_refunded_at
    then
      raise exception
        'Prestador só pode atualizar o andamento da reclamação e a data de solução.';
    end if;

    -- OBS: aqui NÃO checamos provider_status, provider_viewed_at,
    -- solution_deadline_at, solution_deadline_confirmed,
    -- porque esses são justamente os campos liberados para o provider.
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_disputes_lock_solution_deadline()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- 1. Se a data já foi confirmada antes, não deixa mudar mais nada
  if coalesce(old.solution_deadline_confirmed, false) = true then
    if (old.solution_deadline_at is distinct from new.solution_deadline_at)
       or coalesce(new.solution_deadline_confirmed, false) <> true
    then
      raise exception
        'Data de solução já confirmada, não pode ser alterada.';
    end if;

    return new;
  end if;

  -- 2. Se alguém tentar confirmar (FALSE -> TRUE) mudando a data junto
  --    bloqueia. Ou seja: para confirmar, a data precisa ser a mesma.
  if coalesce(new.solution_deadline_confirmed, false) = true
     and (old.solution_deadline_at is distinct from new.solution_deadline_at)
  then
    raise exception
      'Para confirmar a data, não altere o horário na mesma operação. '
      'Primeiro sugira/ajuste a data, depois confirme.';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_jobs_update_conversation_status()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Só nos interessa UPDATE
  IF TG_OP = 'UPDATE' THEN

    -- 1) Job finalizado ou cancelado -> fechar conversa (se não estiver em disputa)
    IF NEW.status IN ('completed', 'cancelled_by_client', 'cancelled_by_provider') THEN
      UPDATE public.conversations c
      SET status = 'closed'
      WHERE c.job_id = NEW.id
        AND c.status <> 'dispute';  -- NÃO FECHA SE ESTIVER EM DISPUTE

    -- 2) (Opcional) Job em andamento -> deixar conversa como active
    ELSIF NEW.status IN ('accepted', 'on_the_way', 'in_progress') THEN
      UPDATE public.conversations c
      SET status = 'active'
      WHERE c.job_id = NEW.id
        AND c.status <> 'dispute';  -- não mexe em disputa
    END IF;

  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_messages_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Função de auditoria antiga para mensagens.
  -- Mantida apenas por compatibilidade, mas não faz mais nada,
  -- pois a auditoria real está em fn_audit_log_message_sent().
  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_messages_before_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.ensure_job_chat_allowed(NEW.conversation_id);
  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_open_job_dispute()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  update public.jobs
  set status = 'dispute'
  where id = new.job_id;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_validate_dispute_insert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  -- Só permite status open na criação
  if new.status <> 'open' then
    raise exception 'Disputa deve ser criada com status open';
  end if;

  -- Job precisa estar completed
  if not exists (
    select 1
    from public.jobs
    where id = new.job_id
      and status = 'completed'
  ) then
    raise exception 'Disputa só pode ser aberta após o serviço ser finalizado';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.trigger_send_push()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- função legacy desativada: envio de push agora é feito pela edge function
  -- que escuta inserções em public.notifications.
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_dispute_provider_status(p_dispute_id uuid, p_new_status text, p_solution_deadline timestamp with time zone DEFAULT NULL::timestamp with time zone, p_confirm_deadline boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- valida status permitido
  if p_new_status not in ('pending', 'viewed', 'contacted', 'solved') then
    raise exception 'Status inválido para provider_status: %', p_new_status;
  end if;

  update public.disputes d
  set
    provider_status = p_new_status,
    -- só preenche a primeira vez que ele realmente viu a disputa
    provider_viewed_at = case
      when p_new_status in ('viewed', 'contacted', 'solved')
           and d.provider_viewed_at is null
      then now()
      else d.provider_viewed_at
    end,
    -- se vier um prazo sugerido, atualiza
    solution_deadline_at = coalesce(p_solution_deadline, d.solution_deadline_at),
    -- se ele marcou que o prazo foi combinado/confirmado com o cliente
    solution_deadline_confirmed = coalesce(p_confirm_deadline, d.solution_deadline_confirmed)
  where d.id = p_dispute_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.update_job_execution_overdue()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_is_overdue boolean := false;
  v_now timestamptz := now();
  v_end_of_day timestamptz;
BEGIN
  -- Se não tiver data agendada, nunca é "fora do prazo"
  IF NEW.scheduled_at IS NOT NULL THEN
    -- fim do dia da data agendada (23:59:59)
    v_end_of_day := date_trunc('day', NEW.scheduled_at) + interval '1 day' - interval '1 second';

    IF v_now > v_end_of_day
       AND NEW.status IN ('accepted', 'on_the_way', 'in_progress')
       AND NEW.status NOT IN ('completed', 'cancelled') THEN
      v_is_overdue := true;
    END IF;
  END IF;

  IF v_is_overdue THEN
    NEW.execution_overdue := true;
    IF NEW.execution_overdue_at IS NULL THEN
      NEW.execution_overdue_at := v_now;
    END IF;
  ELSE
    NEW.execution_overdue := false;
    NEW.execution_overdue_at := NULL;
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_conversation_for_job(p_job_id uuid, p_provider_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_uid uuid;
  v_conv_id uuid;
  v_job record;
  v_title text;
  v_is_client boolean := false;
  v_is_provider boolean := false;
  v_provider_allowed boolean := false;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if p_provider_id is null then
    raise exception 'provider_required';
  end if;

  -- pega dados do job
  select
    j.id,
    j.client_id,
    j.provider_id,
    j.job_code,
    j.title
  into v_job
  from jobs j
  where j.id = p_job_id;

  if not found then
    raise exception 'job_not_found';
  end if;

  v_is_client := (v_job.client_id = v_uid);
  v_is_provider := (p_provider_id = v_uid);

  -- Quem está chamando precisa ser:
  -- - cliente do job, ou
  -- - o próprio provider (p_provider_id = auth.uid())
  if not v_is_client and not v_is_provider then
    raise exception 'not_allowed';
  end if;

  -- Provider alvo precisa ser permitido para esse job:
  -- 1) já está atribuído no job
  if v_job.provider_id is not null and v_job.provider_id = p_provider_id then
    v_provider_allowed := true;
  end if;

  -- 2) ou está aprovado em job_candidates
  if not v_provider_allowed then
    select true
      into v_provider_allowed
    from job_candidates jc
    where jc.job_id = p_job_id
      and jc.provider_id = p_provider_id
      and jc.status = 'approved'
    limit 1;

    v_provider_allowed := coalesce(v_provider_allowed, false);
  end if;

  if not v_provider_allowed then
    raise exception 'not_allowed';
  end if;

  -- define title (nunca null)
  v_title := nullif(trim(coalesce(v_job.job_code::text, '')), '');
  if v_title is null then
    v_title := nullif(trim(coalesce(v_job.title::text, '')), '');
  end if;
  if v_title is null then
    v_title := 'Chat';
  end if;

  -- já existe?
  select c.id
    into v_conv_id
  from conversations c
  where c.job_id = p_job_id
    and c.provider_id = p_provider_id
  limit 1;

  if v_conv_id is not null then
    return v_conv_id;
  end if;

  -- cria
  insert into conversations (
    job_id,
    client_id,
    provider_id,
    title,
    status,
    created_at,
    updated_at,
    last_message_at
  ) values (
    p_job_id,
    v_job.client_id,
    p_provider_id,
    v_title,
    'open',
    now(),
    now(),
    null
  )
  returning id into v_conv_id;

  return v_conv_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.urlencode(string character varying)
 RETURNS text
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/http', $function$urlencode$function$
;

CREATE OR REPLACE FUNCTION public.urlencode(data jsonb)
 RETURNS text
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/http', $function$urlencode_jsonb$function$
;

CREATE OR REPLACE FUNCTION public.urlencode(string bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE STRICT
AS '$libdir/http', $function$urlencode$function$
;

CREATE OR REPLACE FUNCTION public.word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity$function$
;

CREATE OR REPLACE FUNCTION public.word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_commutator_op$function$
;

CREATE OR REPLACE FUNCTION public.word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_commutator_op$function$
;

CREATE OR REPLACE FUNCTION public.word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_op$function$
;

CREATE OR REPLACE FUNCTION public.word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_op$function$
;

