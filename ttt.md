Для удаления домена из названий файлов моков нужно в скрипте Node.js при генерации ключа использовать только путь и параметры URL, без протокола и домена. Аналогично в interceptor надо так же формировать ключ без домена.

Вот как это сделать.

***

## Исправленный Node.js скрипт (extract-mocks.js)

Добавляем функцию для извлечения только пути и query из URL:

```javascript
const url = require('url');

entries.forEach(entry => {
  const { method, url: fullUrl, postData } = entry.request;

  // Разбираем URL, берем только pathname + search
  const parsedUrl = url.parse(fullUrl);
  const pathAndQuery = parsedUrl.pathname + (parsedUrl.search || '');

  let key = `${method}_${pathAndQuery}`.replace(/[^a-z0-9]/gi, '_').toLowerCase();

  if (method === 'POST' && postData && postData.text) {
    const bodyHash = hashCode(postData.text);
    key += `_${bodyHash}`;
  }

  if (!mocks.has(key)) {
    mocks.set(key, {
      method,
      url: fullUrl,
      status: entry.response.status,
      headers: entry.response.headers,
      responseBody: entry.response.content.text || '',
      requestBody: postData ? postData.text : null
    });
  }
});
```

***

## Исправленный Angular MockInterceptor

В Interceptor при формировании ключа делаем тоже самое — извлекаем только path + query из URL:

```typescript
private getPathAndQuery(url: string): string {
  try {
    const parsedUrl = new URL(url);
    return parsedUrl.pathname + (parsedUrl.search || '');
  } catch {
    return url; // fallback
  }
}

private async loadMock(req: HttpRequest<any>): Promise<HttpResponse<any> | null> {
  try {
    const method = req.method;
    const pathAndQuery = this.getPathAndQuery(req.urlWithParams);
    let key = `${method}_${pathAndQuery}`.replace(/[^a-z0-9]/gi, '_').toLowerCase();

    if (method === 'POST' && req.body) {
      const bodyString = JSON.stringify(req.body);
      const hash = this.hashCode(bodyString);
      key += `_${hash}`;
    }

    const response = await fetch(`/assets/mocks/${key}.json`);
    if (!response.ok) return null;

    const mockData = await response.json();
    const body = mockData.responseBody ? JSON.parse(mockData.responseBody) : null;

    return new HttpResponse({
      status: mockData.status,
      body,
      headers: mockData.headers
    });
  } catch {
    return null;
  }
}
```

***

## Итог

- В генерации моков и в interceptor ключ строится из метода + пути + query без домена
- Для POST добавляется хеш тела запроса, чтобы отличать разные payload
- Это обеспечит стабильность mocks, даже если меняется домен или протокол API

Если потребуется, могу помочь с готовой правкой полного кода.

Источники
