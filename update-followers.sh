#!/bin/bash
# パチンカスマン フォロワー数自動更新スクリプト
# 方法①: X API (OAuth 1.0a) でフォロワー数取得 → data.json更新
# 方法②: ブラウザスクレイプ（API失敗時のフォールバック）

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_FILE="$SCRIPT_DIR/data.json"

echo "🎰 パチンカスマン フォロワー数更新開始..."

# === 方法① X API ===
FOLLOWERS=$(python3 -c "
import urllib.request, urllib.error, json, hmac, hashlib, base64, time, uuid, urllib.parse

consumer_key = 'k6GzeV54Ig9NFhzDj0wmsOOqj'
consumer_secret = 'LZ7U8k4B3ee1XkN9sXTOdQBUds19CWFuluvlkgW2heAUEMxNbF'
access_token = '2064535804387663872-dq0p2xrwpWUengQWE0gCVoBH5UVHzP'
access_token_secret = 'nngRG2BYjC43fFYoTfYLMp2wtUimVV8NuEwQxHlWOZprI'

url = 'https://api.twitter.com/2/users/me?user.fields=public_metrics'
method = 'GET'

oauth_params = {
    'oauth_consumer_key': consumer_key,
    'oauth_nonce': uuid.uuid4().hex,
    'oauth_signature_method': 'HMAC-SHA1',
    'oauth_timestamp': str(int(time.time())),
    'oauth_token': access_token,
    'oauth_version': '1.0'
}

parsed = urllib.parse.urlparse(url)
base_url = f'{parsed.scheme}://{parsed.netloc}{parsed.path}'
query_params = dict(urllib.parse.parse_qsl(parsed.query))
all_params = {**oauth_params, **query_params}
param_string = '&'.join(f'{urllib.parse.quote(k, safe=\"\")}={urllib.parse.quote(v, safe=\"\")}' for k, v in sorted(all_params.items()))
base_string = f'{method}&{urllib.parse.quote(base_url, safe=\"\")}&{urllib.parse.quote(param_string, safe=\"\")}'

signing_key = f'{urllib.parse.quote(consumer_secret, safe=\"\")}&{urllib.parse.quote(access_token_secret, safe=\"\")}'
signature = base64.b64encode(hmac.new(signing_key.encode(), base_string.encode(), hashlib.sha1).digest()).decode()
oauth_params['oauth_signature'] = signature

auth_header = 'OAuth ' + ', '.join(f'{k}=\"{urllib.parse.quote(v, safe=\"\")}\"' for k, v in sorted(oauth_params.items()))

req = urllib.request.Request(url, headers={'Authorization': auth_header})
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
        metrics = data['data']['public_metrics']
        print(json.dumps({
            'followers': metrics['followers_count'],
            'following': metrics['following_count'],
            'tweets': metrics['tweet_count'],
            'likes': metrics['like_count']
        }))
except Exception as e:
    print(json.dumps({'error': str(e)}))
" 2>/dev/null)

if echo "$FOLLOWERS" | python3 -c "import sys,json; d=json.load(sys.stdin); assert 'followers' in d" 2>/dev/null; then
    FOLLOWER_COUNT=$(echo "$FOLLOWERS" | python3 -c "import sys,json; print(json.load(sys.stdin)['followers'])")
    echo "✅ X API: フォロワー数 = $FOLLOWER_COUNT"
    
    # data.json更新
    python3 -c "
import json, sys
from datetime import datetime, timezone, timedelta

with open('$DATA_FILE', 'r') as f:
    data = json.load(f)

api_data = json.loads('$FOLLOWERS')
myt = datetime.now(timezone(timedelta(hours=8)))

data['meta']['followers'] = api_data['followers']
data['meta']['lastUpdated'] = myt.strftime('%Y-%m-%dT%H:%M:%S+08:00')
data['meta']['updateSource'] = 'x-api'

# 追加メトリクスも保存
data['meta']['following'] = api_data.get('following', 0)
data['meta']['tweets'] = api_data.get('tweets', 0)
data['meta']['likes'] = api_data.get('likes', 0)

with open('$DATA_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f'✅ data.json更新完了: {api_data[\"followers\"]}フォロワー')
"
else
    echo "❌ X API失敗: $FOLLOWERS"
    echo "→ ブラウザスクレイプで取得してください"
    exit 1
fi

echo ""
echo "🎰 更新完了！GitHub Pagesにpushする場合:"
echo "   cd $SCRIPT_DIR && git add data.json && git commit -m 'update followers' && git push"
