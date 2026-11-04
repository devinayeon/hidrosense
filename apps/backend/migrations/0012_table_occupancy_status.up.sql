UPDATE meja_tanam
SET status_meja = CASE
  WHEN (
    SELECT COALESCE(SUM(
      p.jumlah_tanaman
      - COALESCE((SELECT SUM(k.jumlah_tanaman) FROM kerusakan_tanaman k WHERE k.id_pemindahan = p.id_pemindahan), 0)
      - COALESCE((SELECT SUM(d.jumlah_tanaman) FROM detail_panen d WHERE d.id_pemindahan = p.id_pemindahan), 0)
    ), 0)
    FROM pemindahan p
    WHERE p.id_meja = meja_tanam.id_meja
  ) >= meja_tanam.jumlah_lubang THEN 'penuh'
  ELSE 'tersedia'
END
WHERE lower(status_meja) IN ('tersedia', 'penuh');
