import json, urllib.request

url = "https://api.frankfurter.app/currencies"
data = json.loads(urllib.request.urlopen(url).read())
for code, name in sorted(data.items()):
    print(f"{code}: {name}")
