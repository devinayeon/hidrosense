Jadinya menggunakan yolov11n karena ada modul C2PSA (Cross Stage Partial Spatial Attention) yang dirancang untuk objek kecil. CDPSA menggabungkan koneksi cross-stage partial dengan mekanisme spatial attention. 

Parameter Blok C3k2 pada YOLO11 menggantikan C2f dari YOLOv8 dengan dua kernel konvolusi kecil, bukan satu kernel besar. Harusnya biaya komputasi bisa diefisiensi dengan tetap mempertahankan representasi fitur. Ini juga harusnya berguna karena produk yang dibuat direncanakan secara lokal alias serverless alias model harus jalan ringan di device pengguna.

YOLO11 juga memakai detection head anchor-free yang dioptimalkan. Hal ini mengurangi ketergantungan berlebih pada anchor box bawaan, sehingga adaptasi terhadap objek multi-skala (misalnya ada penyakit kecil yang berdampingan dengan daun selada besar) menjadi lebih baik dan bisa dikenali dibandingkan YOLOv8.

Ya intinya, keunggulan YOLOv11 karena ada C2PSA. Dia bisa ngebantu pada kasus objek yang benar-benar kecil dan backgroundnya rumit. Cuman kalau dari data gambarnya ternyata gejala penyakit atau hama pada selada tergolong besar dan jelas, selisih performa antara YOLOv8n dan YOLOv11n bisa saja tidak terlalu terlihat.

Sistem pada tahap awal mendeteksi tiga jenis hama, yaitu thrips, whitefly (kutu kebul), dan aphids (kutu daun). Jenis hama tersebut dapat dikembangkan lebih lanjut sesuai dengan kebutuhan mitra.