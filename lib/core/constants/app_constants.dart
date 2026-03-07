/// Constantes globais do app
library;

/// URLs e Endpoints
abstract class AppUrls {
  // Supabase
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );
  
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );
}

/// Durations
abstract class AppDurations {
  static const animationShort = Duration(milliseconds: 200);
  static const animationMedium = Duration(milliseconds: 300);
  static const animationLong = Duration(milliseconds: 500);
  
  static const cacheShort = Duration(minutes: 5);
  static const cacheMedium = Duration(minutes: 30);
  static const cacheLong = Duration(hours: 24);
  
  static const requestTimeout = Duration(seconds: 30);
  static const uploadTimeout = Duration(minutes: 2);
}

/// Tamanhos
abstract class AppSizes {
  // Padding
  static const double paddingXs = 4;
  static const double paddingSm = 8;
  static const double paddingMd = 16;
  static const double paddingLg = 24;
  static const double paddingXl = 32;
  
  // Border radius
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radiusRound = 999;
  
  // Icons
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;
  
  // Avatar
  static const double avatarSm = 32;
  static const double avatarMd = 48;
  static const double avatarLg = 64;
  static const double avatarXl = 96;
  
  // Images
  static const double imageThumbWidth = 120;
  static const double imageThumbHeight = 120;
  static const double imagePreviewWidth = 400;
  static const double imagePreviewHeight = 400;
  static const double imageFullWidth = 1080;
  static const double imageFullHeight = 1080;
  
  // Shimmer
  static const double shimmerCardHeight = 120;
  static const double shimmerListItemHeight = 80;
  static const double shimmerAvatarSize = 48;
}

/// Limites
abstract class AppLimits {
  // Paginação
  static const int pageSize = 20;
  static const int maxPageSize = 100;
  
  // Upload
  static const int maxImageSizeMB = 10;
  static const int maxImageSizeBytes = maxImageSizeMB * 1024 * 1024;
  static const int maxImagesPerJob = 10;
  
  // Texto
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 1000;
  static const int maxMessageLength = 500;
  
  // Cache
  static const int maxCacheSize = 100;
  static const int maxCacheAgeDays = 7;
}

/// Regex patterns
abstract class AppPatterns {
  // CPF: 000.000.000-00
  static final cpf = RegExp(r'^\d{3}\.\d{3}\.\d{3}-\d{2}$');
  
  // CNPJ: 00.000.000/0000-00
  static final cnpj = RegExp(r'^\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}$');
  
  // Telefone: (00) 00000-0000
  static final phone = RegExp(r'^\(\d{2}\) \d{5}-\d{4}$');
  
  // Email
  static final email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  // CEP: 00000-000
  static final cep = RegExp(r'^\d{5}-\d{3}$');
}

/// Tipos de serviço
abstract class ServiceTypes {
  static const eletricista = 'Eletricista';
  static const encanador = 'Encanador';
  static const pedreiro = 'Pedreiro';
  static const pintor = 'Pintor';
  static const marceneiro = 'Marceneiro';
  static const jardineiro = 'Jardineiro';
  static const chaveiro = 'Chaveiro';
  static const limpeza = 'Limpeza';
  static const mudanca = 'Mudança';
  static const outros = 'Outros';
  
  static const all = [
    eletricista,
    encanador,
    pedreiro,
    pintor,
    marceneiro,
    jardineiro,
    chaveiro,
    limpeza,
    mudanca,
    outros,
  ];
}

/// Status de Job
abstract class JobStatus {
  static const waitingProviders = 'waiting_providers';
  static const proposed = 'proposed';
  static const accepted = 'accepted';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const disputed = 'disputed';
}

/// Roles
abstract class UserRoles {
  static const client = 'client';
  static const provider = 'provider';
  static const admin = 'admin';
}
