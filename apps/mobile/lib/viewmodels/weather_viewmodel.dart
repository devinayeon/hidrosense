import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_model.dart';

class WeatherState {
  final WeatherData? data;
  final bool isLoading;
  final String? errorMessage;

  const WeatherState({this.data, this.isLoading = false, this.errorMessage});

  WeatherState copyWith({
    WeatherData? data,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WeatherState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

typedef WeatherLoader = Future<WeatherData> Function();

/// Data contoh selama integrasi BMKG belum tersedia (P0 ditunda).
Future<WeatherData> loadDemoWeather() async {
  await Future.delayed(const Duration(milliseconds: 300));

  return const WeatherData(
    lokasi: 'LOKASI PERKEBUNAN NFT',
    kota: 'Ambulu, Jember',
    sumber: 'Sumber: data contoh, BMKG belum terhubung',
    suhu: 28,
    statusSuhu: 'Stabil',
    kelembapan: 82,
    statusKelembapan: 'Udara Basah',
    curahHujan: 'Hujan Ringan',
    estimasiHujan: 'Estimasi sore hari',
    kecepatanAngin: 12,
    arahAngin: 'Arah Barat Daya',
    prakiraanHarian: [
      PrakiraanHarian(
        waktu: 'Pagi (07:00 - 11:00)',
        status: 'Cerah Berawan',
        suhu: 26,
        ringkasanSaran:
            'Pagi ini cuaca ideal. Waktu terbaik untuk pemberian nutrisi dan inspeksi instalasi.',
        rekomendasiList: [
          TindakanRekomendasi(
            judul: 'Cek EC dan pH Larutan Nutrisi',
            deskripsi:
                'Pastikan nilai EC berada pada rentang optimal 1.4 - 1.8 mS/cm sebelum suhu naik.',
            alasan:
                'Alasan: Penyerapan nutrisi tanaman paling maksimal saat pagi hari.',
            labelTag: 'Rutin',
            isPenting: false,
          ),
        ],
      ),
      PrakiraanHarian(
        waktu: 'Siang (12:00 - 15:00)',
        status: 'Berawan Tebal',
        suhu: 31,
        ringkasanSaran:
            'Suhu udara cukup tinggi. Waspadai kenaikan suhu air tandon nutrisi.',
        rekomendasiList: [
          TindakanRekomendasi(
            judul: 'Optimalkan Debit Air Sirkulasi',
            deskripsi:
                'Pastikan pompa bekerja stabil untuk mencegah akar kepanasan.',
            alasan:
                'Alasan: Suhu tandon yang tinggi mengurangi kandungan oksigen terlarut.',
            labelTag: 'Penting',
            isPenting: true,
          ),
        ],
      ),
      PrakiraanHarian(
        waktu: 'Sore (16:00 - 18:00)',
        status: 'Hujan Ringan',
        suhu: 28,
        ringkasanSaran:
            'Sore ini diprediksi Hujan Ringan. Lindungi sirkulasi meja NFT Anda.',
        rekomendasiList: [
          TindakanRekomendasi(
            judul: 'Atur Debit & Kepekatan Nutrisi',
            deskripsi:
                'Mengurangi risiko pengenceran AB Mix akibat rembesan air hujan. Jaga EC di level 1.2 - 1.4 mS/cm.',
            alasan:
                'Alasan: Curah hujan meningkatkan volume air tawar di penampung terbuka.',
            labelTag: 'Penting',
            isPenting: true,
          ),
          TindakanRekomendasi(
            judul: 'Jadwal Semprot Pencegahan Jamur',
            deskripsi:
                'Lakukan penyemprotan tipis neem oil pada pukul 16:30 WIB sebelum hujan turun deras.',
            alasan:
                'Alasan: Kelembapan tinggi memicu pertumbuhan spora jamur malam hari.',
            labelTag: 'Rutin',
            isPenting: false,
          ),
        ],
      ),
    ],
    lastUpdated: 'Data contoh statis, bukan pembaruan BMKG langsung',
  );
}

class WeatherViewModel extends StateNotifier<WeatherState> {
  WeatherViewModel({WeatherLoader? loader, bool autoLoad = true})
    : _loader = loader ?? loadDemoWeather,
      super(const WeatherState()) {
    if (autoLoad) fetchWeatherData();
  }

  final WeatherLoader _loader;
  int _requestGeneration = 0;

  Future<void> fetchWeatherData() async {
    final generation = ++_requestGeneration;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final data = await _loader();
      if (!mounted || generation != _requestGeneration) return;
      state = WeatherState(data: data, isLoading: false);
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Gagal memuat data cuaca. Data contoh tidak dapat ditampilkan.',
      );
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    super.dispose();
  }
}

final weatherViewModelProvider =
    StateNotifierProvider.autoDispose<WeatherViewModel, WeatherState>((ref) {
      return WeatherViewModel();
    });
