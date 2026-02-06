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