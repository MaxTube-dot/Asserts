Вот полный пример, который демонстрирует:

1. Как из HAR экспортировать моки (GET и POST запросы с учётом тела для POST).
2. Как эти моки использовать в Angular HTTP Interceptor для отдачи моковых ответов.

***

# 1. Node.js скрипт для генерации моков из HAR

Создайте файл `extract-mocks.js` в корне проекта рядом с HAR:

```javascript
const fs = require('fs');
const path = require('path');

const harFile = 'network.har';   // Путь к HAR файлу
const outputDir = path.resolve(__dirname, 'src/assets/mocks');

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const har = JSON.parse(fs.readFileSync(harFile, 'utf-8'));
const entries = har.log.entries;

function hashCode(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = Math.imul(31, hash) + str.charCodeAt(i) | 0;
  }
  return Math.abs(hash).toString();
}

const mocks = new Map();

entries.forEach(entry => {
  const { method, url, postData } = entry.request;
  let key = `${method}_${url}`.replace(/[^a-z0-9]/gi, '_').toLowerCase();

  if (method === 'POST' && postData && postData.text) {
    const bodyHash = hashCode(postData.text);
    key += `_${bodyHash}`;
  }

  if (!mocks.has(key)) {
    mocks.set(key, {
      method,
      url,
      status: entry.response.status,
      headers: entry.response.headers,
      responseBody: entry.response.content.text || '',
      requestBody: postData ? postData.text : null
    });
  }
});

mocks.forEach((value, key) => {
  fs.writeFileSync(path.join(outputDir, `${key}.json`), JSON.stringify(value, null, 2));
});

console.log(`Exported ${mocks.size} mock(s) to ${outputDir}`);
```

Запустите скрипт командой:

```bash
node extract-mocks.js
```

В папке `src/assets/mocks` появятся JSON-файлы с отдельно подготовленными моками, уникальными по сочетанию метода + URL + (для POST) телу запроса.

***

# 2. Angular HTTP Interceptor для отдачи моков

Создайте файл `mock.interceptor.ts` в вашем Angular проекте:

```typescript
import { Injectable } from '@angular/core';
import {
  HttpInterceptor,
  HttpRequest,
  HttpHandler,
  HttpEvent,
  HttpResponse
} from '@angular/common/http';
import { Observable, from, of } from 'rxjs';
import { switchMap, delay, catchError } from 'rxjs/operators';

@Injectable()
export class MockInterceptor implements HttpInterceptor {
  private async loadMock(req: HttpRequest<any>): Promise<HttpResponse<any> | null> {
    try {
      const method = req.method;
      let key = `${method}_${req.urlWithParams}`.replace(/[^a-z0-9]/gi, '_').toLowerCase();

      if (method === 'POST' && req.body) {
        const bodyString = JSON.stringify(req.body);
        const hash = this.hashCode(bodyString);
        key += `_${hash}`;
      }

      // Загружаем файл моков из assets
      const response = await fetch(`/assets/mocks/${key}.json`);
      if (!response.ok) {
        return null;
      }
      const mockData = await response.json();

      // Формируем HttpResponse с моковыми данными
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

  private hashCode(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = Math.imul(31, hash) + str.charCodeAt(i) | 0;
    }
    return Math.abs(hash).toString();
  }

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    return from(this.loadMock(req)).pipe(
      switchMap(mockResponse => {
        if (mockResponse) {
          // Создаем искусственную задержку для реалистичности
          return of(mockResponse).pipe(delay(300));
        }
        return next.handle(req);
      }),
      catchError(() => next.handle(req))
    );
  }
}
```

***

# 3. Регистрация Interceptor в AppModule

В `app.module.ts` добавьте:

```typescript
import { HTTP_INTERCEPTORS } from '@angular/common/http';
import { MockInterceptor } from './mock.interceptor';

@NgModule({
  providers: [
    {
      provide: HTTP_INTERCEPTORS,
      useClass: MockInterceptor,
      multi: true
    }
  ]
})
export class AppModule {}
```

***

# Объяснения

- HAR скрипт создаст уникальные ключи для GET и POST (учитывая тело POST).
- JSON файлы моков попадают в `src/assets/mocks` и автоматически доступны как часть сборки Angular.
- Interceptor по ключу (метод + URL + хеш тела) пытается загрузить локальный мок из assets.
- Если мок найден — вернётся моковый ответ, иначе запрос пройдет к живому API.
- При этом можно спокойно обрабатывать большое количество уникальных POST-запросов с разными телами.

Если нужны подробности или помощь с конкретными частями, спрашивайте!

Источники
