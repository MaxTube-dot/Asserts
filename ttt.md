Самый простой и лёгкий путь для вашей задачи — использовать Node.js скрипт для чтения HAR, фильтрации и экспорта необходимых запросов в отдельные JSON файлы, а затем на стороне Angular сделать HTTP Interceptor, который будет подставлять моковые ответы, считывая их из этих файлов.

***

## Пример простой реализации

### 1. Node.js скрипт для экспорта из HAR

Создаём файл `extract-mocks.js` рядом с HAR файлом:

```javascript
const fs = require('fs');
const path = require('path');

const harFile = 'network.har'; // ваш исходный HAR файл с запросами
const outputDir = path.resolve(__dirname, 'mocks');

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir);
}

const har = JSON.parse(fs.readFileSync(harFile, 'utf-8'));
const entries = har.log.entries;

const uniqueRequests = new Map();

entries.forEach(entry => {
  const { method, url } = entry.request;
  // Ключ по методу и URL
  const key = `${method}_${url}`.replace(/[^a-z0-9]/gi, '_').toLowerCase();

  if (!uniqueRequests.has(key)) {
    uniqueRequests.set(key, {
      url,
      method,
      status: entry.response.status,
      response: entry.response.content.text || '',
      headers: entry.response.headers
    });
  }
});

uniqueRequests.forEach((value, key) => {
  fs.writeFileSync(
    path.join(outputDir, `${key}.json`),
    JSON.stringify(value, null, 2)
  );
});

console.log(`Exported ${uniqueRequests.size} mocks to ${outputDir}`);
```

Запускаем командой:

```bash
node extract-mocks.js
```

В итоге вы получите папку `mocks/` с JSON-файлами на каждый уникальный запрос.

***

### 2. Angular HTTP Interceptor, использующий эти файлы

Предполагается, что моки помещены в папку `src/assets/mocks` и доступны клиенту.

```typescript
import { Injectable } from '@angular/core';
import {
  HttpInterceptor,
  HttpRequest,
  HttpHandler,
  HttpResponse,
  HttpEvent
} from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { delay, switchMap } from 'rxjs/operators';

@Injectable()
export class MockInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    // Формируем имя файла mock по запросу
    const key = `${req.method}_${req.urlWithParams}`.replace(/[^a-z0-9]/gi, '_').toLowerCase();
    const mockUrl = `/assets/mocks/${key}.json`;

    return fetch(mockUrl).then(res => {
      if (res.ok) {
        return res.json();
      }
      throw new Error('Mock file not found');
    })
    .then(mockData => {
      return of(new HttpResponse({
        status: mockData.status,
        body: JSON.parse(mockData.response || '{}')
      })).pipe(delay(500)); // Имитация задержки сети
    })
    .catch(() => {
      // Если мока нет, просто пропускаем запрос дальше
      return next.handle(req);
    }) as unknown as Observable<HttpEvent<any>>;
  }
}
```

***

### Простое добавление в Angular

В `app.module.ts`:

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

## Итог

- HAR экспортируете привычным инструментом браузера
- Запускаете `extract-mocks.js` для автоматического разделения HAR по отдельным mock JSON
- Копируете `mocks/` в `src/assets/mocks`
- Запускаете Angular с MockInterceptor, который отдаёт моковые ответы из файлов

Этот способ:

- Максимально прост в реализации
- Не требует backend-сервера
- Легко расширяется добавлением новых запросов
- Поддерживает любые нестандартные ответные данные и логику в HAR

Если нужно, могу помочь с расширенным примером или уточнениями по интеграции.

Источники
