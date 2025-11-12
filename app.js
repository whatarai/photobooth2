// PhotoBooth React 元件 (UMD 版，可上傳邊框 + 拍多張照片)
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
  const [frameImg, setFrameImg] = useState(null); // 新增邊框
  const [capturedPhotos, setCapturedPhotos] = useState([]); // 暫存照片
  const [width] = useState(720);
  const [height] = useState(540);
  const [errorMsg, setErrorMsg] = useState('');

  // Permissions API
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

  // Request Camera
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

  // Cleanup
  useEffect(() => {
    return () => { if (stream) stream.getTracks().forEach(t => t.stop()); };
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

    // Stickers
    stickerFiles.forEach(s => {
      if (!s.img) return;
      ctx.save();
      const w = s.img.width * s.scale;
      const h = s.img.height * s.scale;
      ctx.drawImage(s.img, s.x - w/2, s.y - h/2, w, h);
      ctx.restore();
    });

    // Frame (邊框)
    if (frameImg) ctx.drawImage(frameImg, 0, 0, width, height);

    ctx.restore();
  };

  useEffect(() => {
    const preview = canvasRef.current;
    if (!preview) return;
    preview.width = width;
    preview.height = height;
    const ctx = preview.ge
