export default async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    return res.status(200).end();
  }

  const target = new URL('https://www.datos.gov.co/resource/p6dx-8zbt.json');
  const reqUrl = new URL(req.url, `https://${req.headers.host}`);
  reqUrl.searchParams.forEach((v, k) => target.searchParams.set(k, v));

  try {
    const r = await fetch(target.toString(), {
      headers: { 'Accept': 'application/json' }
    });
    if (!r.ok) return res.status(r.status).json({ error: 'SECOP API: ' + r.status });
    const data = await r.json();

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 'public, s-maxage=300');
    return res.status(200).json(data);
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
