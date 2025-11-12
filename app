// PhotoBooth React 元件
// 可直接用於單檔 GitHub Pages，HTTPS 環境即可使用相機

const { useState, useRef, useEffect } = React;

function PhotoBooth() {
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const [stream, setStream] = useState(null);
  const [permissionState, setPermissionState] = useState('unknown');
  const [filter, setFilter] = useState('none');
  const [stickerFiles, setStickerFiles] = useState([]);
  const [selectedStickerId, setSelectedStickerId] = useState(null);
  const [backgroundImg, setBackgroundImg] = useState(null);
  const [width] = useState(720);
  const [height] = useState(540);
  const [errorMsg, setErrorMsg] = useState('');

  // Permissions API 檢查
  useEffect(() => {
    let mounted = true;
    async function checkPermission() {
      if (!navigator.permissions || !navigator.permissions.query) {
        if (mounted) setPermissionState('unsupported');
        return;
      }
      try {
        const p = await navigator.permissions.query({ name: 'camera' });
        if (!mounted) return;
        setPermissionState(p.state);
        p.onchange = () => setPermissionState(p.state);
      } catch (e) {
        if (mounted) setPermissionState('unsupported');
      }
    }
    checkPermission();
    return () => { mounted = false; };
  }, []);

  // 申請相機
  const requestCamera = async () => {
    setErrorMsg('');
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      setErrorMsg('瀏覽器不支援相機存取。');
      setPermissionState('unsupported');
      return false;
    }

    try {
      const s = await navigator.mediaDevices.getUserMedia({ video: { width: 1280, height: 720 }, audio: false });
      if (stream) stream.getTracks().forEach(t => t.stop());
      setStream(s);
      setPermissionState('granted');
      if (videoRef.current) {
        videoRef.current.srcObject = s;
        try { await videoRef.current.play(); } catch (e) {}
      }
      return true;
    } catch (e) {
      const msg = (e && e.name) ? e.name : String(e);
      if (msg.includes('NotAllowed') || msg.includes('Permission')) {
        setErrorMsg('您已拒絕相機權限或瀏覽器阻擋了相機存取。');
        setPermissionState('denied');
      } else if (msg.includes('NotFound') || msg.includes('DevicesNotFound')) {
        setErrorMsg('找不到相機裝置。');
        setPermissionState('denied');
      } else {
        setErrorMsg('無法存取相機：' + msg);
      }
      return false;
    }
  };

  // 清理 Stream
  useEffect(() => {
    return () => {
      if (stream) stream.getTracks().forEach(t => t.stop());
    };
  }, [stream]);

  const cssFilterFromKey = (key) => {
    switch (key) {
      case 'grayscale': return 'grayscale(100%)';
      case 'sepia': return 'sepia(80%)';
      case 'invert': return 'invert(100%)';
      case 'blur': return 'blur(3px)';
      default: return 'none';
    }
  };

  // Canvas 畫面
  const drawToCanvas = (ctx) => {
    if (!ctx) return;
    ctx.save();
    ctx.clearRect(0, 0, width, height);
    ctx.filter = cssFilterFromKey(filter);

    const hasVideo = stream && videoRef.current && videoRef.current.readyState >= 2;
    if (hasVideo) {
      ctx.translate(width, 0);
      ctx.scale(-1, 1);
      try { ctx.drawImage(videoRef.current, 0, 0, width, height); } catch (e) {}
      ctx.setTransform(1, 0, 0, 1, 0, 0);
    } else if (backgroundImg) {
      const img = backgroundImg;
      const arCanvas = width / height;
      const arImg = img.width / img.height;
      let drawW = width, drawH = height, offsetX = 0, offsetY = 0;
      if (arImg > arCanvas) {
        drawH = height;
        drawW = img.width * (height / img.height);
        offsetX = -(drawW - width) / 2;
      } else {
        drawW = width;
        drawH = img.height * (width / img.width);
        offsetY = -(drawH - height) / 2;
      }
      ctx.drawImage(img, offsetX, offsetY, drawW, drawH);
    } else {
      ctx.fillStyle = '#f0f0f0';
      ctx.fillRect(0, 0, width, height);
      ctx.fillStyle = '#666';
      ctx.font = '16px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('相機不可用', width / 2, height / 2 - 10);
      ctx.font = '13px sans-serif';
      ctx.fillText('請按「重新請求相機」或上傳背景圖片作為替代', width / 2, height / 2 + 14);
    }

    // 貼圖
    stickerFiles.forEach(s => {
      if (!s.img) return;
      ctx.save();
      const w = s.img.width * s.scale;
      const h = s.img.height * s.scale;
      ctx.drawImage(s.img, s.x - w / 2, s.y - h / 2, w, h);
      ctx.restore();
    });

    ctx.restore();
  };

  useEffect(() => {
    const preview = canvasRef.current;
    if (!preview) return;
    preview.width = width;
    preview.height = height;
    const ctx = preview.getContext('2d');
    let raf = 0;
    const loop = () => {
      drawToCanvas(ctx);
      raf = requestAnimationFrame(loop);
    };
    loop();
    return () => cancelAnimationFrame(raf);
  }, [stream, filter, stickerFiles, backgroundImg]);

  // 拍照
  const takePhoto = (photostrip = false) => {
    const preview = canvasRef.current;
    if (!preview) return;
    if (!photostrip) {
      downloadURL(preview.toDataURL('image/png'), 'photobooth.png');
    } else {
      const rows = 4;
      const c = document.createElement('canvas');
      c.width = width;
      c.height = height * rows;
      const ctx = c.getContext('2d');
      for (let i = 0; i < rows; i++) {
        ctx.drawImage(preview, 0, i * height);
      }
      downloadURL(c.toDataURL('image/png'), 'photostrip.png');
    }
  };

  const downloadURL = (url, filename) => {
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
  };

  // 貼圖上傳
  const handleStickerUpload = (e) => {
    const files = Array.from(e.target.files || []);
    files.forEach(file => {
      const reader = new FileReader();
      reader.onload = () => {
        const img = new Image();
        img.onload = () => setStickerFiles(prev => [...prev, { id: Date.now() + Math.random(), img, x: width / 2, y: height / 2, scale: 0.5 }]);
        img.src = reader.result;
      };
      reader.readAsDataURL(file);
    });
    e.target.value = null;
  };

  // 背景上傳
  const handleBackgroundUpload = (e) => {
    const file = e.target.files && e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => {
      const img = new Image();
      img.onload = () => setBackgroundImg(img);
      img.src = reader.result;
    };
    reader.readAsDataURL(file);
    e.target.value = null;
  };

  const handleCanvasClick = (ev) => {
    const rect = ev.currentTarget.getBoundingClientRect();
    const cx = (ev.clientX - rect.left) * (width / rect.width);
    const cy = (ev.clientY - rect.top) * (height / rect.height);
    if (selectedStickerId) {
      setStickerFiles(prev => prev.map(s => s.id === selectedStickerId ? { ...s, x: cx, y: cy } : s));
      setSelectedStickerId(null);
    }
  };

  return (
    <div className="p-4 max-w-5xl mx-auto">
      <h2 className="text-2xl font-semibold mb-3">線上拍貼機</h2>
      <p className="mb-3 text-sm opacity-80">此頁面需要 HTTPS 才能使用相機，若無法使用可上傳背景替代。</p>

      {errorMsg && <div className="bg-red-100 text-red-700 p-2 mb-3 rounded">{errorMsg}</div>}

      <div className="mb-3 flex gap-2 items-center">
        <button onClick={requestCamera} className="px-3 py-2 rounded bg-indigo-600 text-white">重新請求相機</button>
        <label className="cursor-pointer px-3 py-2 bg-gray-200 rounded">
          上傳背景
          <input type="file" accept="image/*" onChange={handleBackgroundUpload} className="hidden" />
        </label>
        <div className="text-sm text-gray-600">相機權限：{permissionState}</div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="md:col-span-2 space-y-3">
          <div className="bg-gray-100 rounded-lg p-2 flex flex-col items-center">
            <div className="relative">
              <video ref={videoRef} className="hidden" playsInline muted></video>
              <canvas ref={canvasRef} onClick={handleCanvasClick} style={{ width: '100%', maxWidth: '720px', height: 'auto', cursor: selectedStickerId ? 'crosshair' : 'default', borderRadius: 8, boxShadow: '0 6px 18px rgba(0,0,0,0.12)' }} />
              <div className="absolute left-2 top-2 text-xs bg-black bg-opacity-30 text-white rounded px-2 py-1">Preview - filter: {filter}</div>
            </div>
            <div className="mt-3 flex gap-2 flex-wrap">
              <button className="px-3 py-2 rounded bg-blue-600 text-white" onClick={() => takePhoto(false)}>拍照(下載)</button>
              <button className="px-3 py-2 rounded bg-pink-600 text-white" onClick={() => takePhoto(true)}>拍貼條(4張)</button>
              <select value={filter} onChange={e => setFilter(e.target.value)} className="px-2 py-1 rounded border">
                <option value="none">無濾鏡</option>
                <option value="grayscale">黑白</option>
                <option value="sepia">古銅</option>
                <option value="invert">反轉</option>
                <option value="blur">模糊</option>
              </select>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// 渲染
const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<PhotoBooth />);
