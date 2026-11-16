// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get homeJukebox => 'Jukebox de sonidos';

  @override
  String get homeJukeboxSub => 'Solo sonido de fondo, sin cuento';

  @override
  String get homeTales => 'Cuentos';

  @override
  String get homeNowPlaying => 'Sonando ahora';

  @override
  String get detailVoice => 'Voz';

  @override
  String get detailNoScript => 'No se pudo cargar el cuento.';

  @override
  String get detailBackground => 'Fondo';

  @override
  String get detailRecommended => 'Recomendado';

  @override
  String get detailNoBackground => 'Sin fondo';

  @override
  String get detailRitual => 'Ritual de «buenas noches»';

  @override
  String get detailRitualSub =>
      'Primero solo el fondo, y sigue sonando un rato después del cuento';

  @override
  String get detailPlay => 'Reproducir';

  @override
  String get detailFavourite => 'Favorito';

  @override
  String get playerIntro => 'Solo el fondo…';

  @override
  String get playerStartNow => 'Empezar ya';

  @override
  String get playerVoice => 'Cuento';

  @override
  String get playerTail => 'El fondo se apaga';

  @override
  String get playerFadeOut => 'Bajando el volumen…';

  @override
  String get playerDone => 'Buenas noches';

  @override
  String get playerMixer => 'Jukebox';

  @override
  String get playerBalance => 'Voz ↔ fondo';

  @override
  String get playerBackground => 'Fondo';

  @override
  String get playerStop => 'Detener';

  @override
  String get playerNothing => 'No suena nada';

  @override
  String get mixerTitle => 'Jukebox de sonidos';

  @override
  String get mixerMain => 'Sonido principal';

  @override
  String get mixerSecondary => 'Sonido secundario';

  @override
  String get mixerAddLayer => 'Añadir capa';

  @override
  String get mixerPresets => 'Mezclas guardadas';

  @override
  String get mixerSavePreset => 'Guardar mezcla';

  @override
  String get mixerPresetName => 'Nombre de la mezcla';

  @override
  String get mixerSave => 'Guardar';

  @override
  String get mixerCancel => 'Cancelar';

  @override
  String get mixerDeletePreset => '¿Borrar la mezcla?';

  @override
  String get mixerDelete => 'Borrar';

  @override
  String get mixerRemoveLayer => 'Quitar capa';

  @override
  String get mixerGroupNature => 'Sonidos de la naturaleza';

  @override
  String get mixerGroupMusic => 'Nanas';

  @override
  String get timerTitle => 'Temporizador';

  @override
  String get timerOff => 'Apagado';

  @override
  String get timerEndOfTale => 'Al terminar el cuento';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsBreathing => 'Círculo que respira';

  @override
  String get settingsBreathingSub =>
      'El único movimiento en la pantalla del reproductor';

  @override
  String get settingsIntro => 'Fondo antes del cuento (ritual)';

  @override
  String get settingsTail => 'Fondo después del cuento (ritual)';

  @override
  String get settingsTimer => 'Temporizador predeterminado';

  @override
  String get settingsCatalog => 'Catálogo';

  @override
  String get settingsCheckUpdates => 'Buscar actualizaciones';

  @override
  String get settingsChecking => 'Comprobando…';

  @override
  String get settingsUpToDate => 'El catálogo está al día';

  @override
  String get settingsUpdated => 'Catálogo actualizado';

  @override
  String get settingsOffline => 'Sin conexión: todo funciona sin internet';

  @override
  String get settingsVoice => 'Voz';

  @override
  String get settingsVocative => 'Cómo llamar a tu hijo';

  @override
  String get settingsVocativeSub =>
      'El nombre con el que llamas a tu hijo o hija, p. ej. Anita. Aún no se usa.';

  @override
  String get settingsVocativeNone => 'Sin configurar';

  @override
  String get settingsPrivacy =>
      'Sin cuenta, sin anuncios y sin analíticas de terceros. La red se usa para actualizar el catálogo y para estadísticas de uso anónimas, si están activadas.';

  @override
  String get settingsPrivacyCloning =>
      'Sin cuenta, sin anuncios y sin analíticas de terceros. La red se usa para actualizar el catálogo, para tu voz grabada y para estadísticas de uso anónimas, si están activadas.';

  @override
  String get settingsStats => 'Estadísticas de uso anónimas';

  @override
  String get settingsStatsSub =>
      'Ayudan a saber qué funciona en la app. Sin identificador del dispositivo, nada sobre tu hijo ni sobre tus grabaciones.';

  @override
  String get voiceTitle => 'Voz';

  @override
  String get voiceSystem => 'Voz del teléfono';

  @override
  String get voiceSystemSub => 'Funciona al momento y sin internet';

  @override
  String get voiceRecord => 'Grabar mi voz';

  @override
  String get voiceBeta =>
      'Versión de prueba gratuita. La voz tarda unas horas en prepararse.';

  @override
  String get voicePending =>
      'Tu voz se está preparando, estará lista por la mañana';

  @override
  String get voiceReady => 'Lista';

  @override
  String get voiceWaiting => 'La voz está lista, esperando las primeras frases';

  @override
  String get voiceFailed =>
      'No se pudo crear la voz. Prueba a grabar de nuevo.';

  @override
  String get voiceDelete => 'Borrar voz';

  @override
  String get voiceCancel => 'Cancelar';

  @override
  String get voiceMissingClips =>
      'Las frases que aún no se han descargado las leerá por ahora la voz del teléfono.';

  @override
  String get voiceHintTitle => 'El teléfono no tiene voz en español';

  @override
  String get voiceHintIos =>
      'Instala una en Ajustes → Accesibilidad → Contenido leído → Voces → Español (mejor una voz mejorada o prémium).';

  @override
  String get voiceHintAndroid =>
      'Instala una en Ajustes → Salida de texto a voz → Google → Instalar datos de voz → Español.';

  @override
  String get voiceHintOk => 'Entendido';

  @override
  String get recTitle => 'Grabar mi voz';

  @override
  String get recName => 'Tu nombre';

  @override
  String get recNameHint => 'p. ej. Ana';

  @override
  String get recTips => 'Antes de empezar';

  @override
  String get recRead => 'Lee en voz alta';

  @override
  String get recConsent =>
      'Acepto que Hajánek cree mi voz a partir de mi grabación. La grabación y la voz se guardan solo en el servidor de Hajánek y puedo borrarlas cuando quiera.';

  @override
  String get recStart => 'Grabar';

  @override
  String get recStop => 'Listo';

  @override
  String get recReadHint =>
      'Mientras grabas, el texto avanza contigo. Si se adelanta o se queda atrás, toca la línea que estás leyendo.';

  @override
  String get recReadyHint => 'sigue leyendo, se detiene solo a los 30 s';

  @override
  String get recPlay => 'Escuchar';

  @override
  String get recPause => 'Detener';

  @override
  String get recAgain => 'Grabar de nuevo';

  @override
  String get recUpload => 'Enviar';

  @override
  String get recUploading => 'Enviando…';

  @override
  String get recNoMic =>
      'Sin acceso al micrófono no se puede: actívalo en Ajustes.';

  @override
  String get recFailed => 'No se pudo grabar. Inténtalo de nuevo, por favor.';

  @override
  String get pairTv => 'Conectar la tele';

  @override
  String get pairTvSub => 'Así tu voz también leerá los cuentos en la tele';

  @override
  String get pairTvHelp =>
      'En la tele, abre Hajánek → Voz → Conectar con el teléfono. Aparecerá un código de seis cifras.';

  @override
  String get pairCode => 'Código de la tele';

  @override
  String get pairConfirm => 'Conectar';

  @override
  String get pairTvDone =>
      'La tele está conectada; las voces se descargarán en ella solas.';

  @override
  String get pairBadCode =>
      'Este código no coincide o ha caducado. Compruébalo en la tele.';

  @override
  String get tvVoice => 'Voz';

  @override
  String get tvBackground => 'Fondo';

  @override
  String get tvSettings => 'Ajustes';

  @override
  String get tvOn => 'activado';

  @override
  String get tvOff => 'desactivado';

  @override
  String get tvPause => 'Pausa';

  @override
  String get tvResume => 'Continuar';

  @override
  String get tvFavourite => 'Favorito';

  @override
  String get tvUnfavourite => 'Quitar de favoritos';

  @override
  String get tvJukeboxSub => 'Elige un fondo, suena sin cuento';

  @override
  String get tvBalance => 'Voz ↔ fondo';

  @override
  String get voiceSystemTv => 'Voz de la tele';

  @override
  String get voiceSystemTvSub => 'Sin internet, si la tele habla español';

  @override
  String get voiceParentTvHint =>
      'La voz de mamá o papá se graba en el teléfono. Conecta la tele con el teléfono y las voces se descargarán aquí solas.';

  @override
  String get voiceHintTitleTv => 'La tele no tiene voz en español';

  @override
  String get voiceHintTv =>
      'Los cuentos los puede leer la voz de mamá o papá: grábala en el teléfono y conecta la tele (Voz → Conectar con el teléfono). Sin ella, solo suena el fondo.';

  @override
  String get pairTitle => 'Conectar con el teléfono';

  @override
  String get pairSub => 'La voz de mamá o papá se graba en el teléfono';

  @override
  String get pairInstructions =>
      'En el teléfono, abre Hajánek → Voz → Conectar la tele e introduce el código';

  @override
  String get pairWaiting => 'Esperando al teléfono…';

  @override
  String get pairDone =>
      'Conectado. Las voces se están descargando en la tele.';

  @override
  String get pairExpired => 'El código ha caducado.';

  @override
  String get pairNewCode => 'Código nuevo';

  @override
  String get pairClose => 'Listo';

  @override
  String minutes(int n) {
    return '$n min';
  }

  @override
  String detailAge(String age) {
    return 'edad $age';
  }

  @override
  String playerIntroLeft(String left) {
    return 'El cuento empieza en $left';
  }

  @override
  String get sectionUvod => 'Preparación';

  @override
  String get sectionVstup => 'Entrada al cuento';

  @override
  String get sectionPribeh => 'Historia';

  @override
  String get sectionDojezd => 'Despedida';

  @override
  String settingsCatalogVersion(int v) {
    return 'Versión del catálogo $v';
  }

  @override
  String seconds(int n) {
    return '$n s';
  }

  @override
  String voiceDownloading(int done, int total) {
    return 'Descargando la voz: $done de $total frases';
  }

  @override
  String voiceDeleteConfirm(String name) {
    return '¿Borrar la voz «$name»? La grabación y todas las frases se borrarán del teléfono y del servidor.';
  }

  @override
  String recMinHint(int s) {
    return 'puedes terminar a los $s s';
  }

  @override
  String get balanceVoiceOnly => 'Solo voz';

  @override
  String get balanceMoreVoice => 'Más voz';

  @override
  String get balanceEven => 'Equilibrado';

  @override
  String get balanceMoreBackground => 'Más fondo';

  @override
  String get balanceBackgroundOnly => 'Solo fondo';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSub => 'Idioma de la app, de los cuentos y de la voz';

  @override
  String get languageSystem => 'Igual que el teléfono';

  @override
  String get playerChannel => 'Reproducción';
}
