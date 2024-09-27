Чтобы добавить анимацию плавного исчезновения и появления для компонента app-banner-components-wrapper при изменении текущего баннера, вы можете воспользоваться Angular Animations. Ниже приведённый пример включает настройки необходимых анимаций и их применение в вашем коде.

### Шаг 1: Установка Angular Animations

Убедитесь, что ваш проект уже поддерживает анимации. Если нет, установите необходимые пакеты:

npm install @angular/animations


### Шаг 2: Импортировать модули

Импортируйте BrowserAnimationsModule в ваш основной модуль приложения (обычно app.module.ts):

import { BrowserAnimationsModule } from '@angular/platform-browser/animations';

@NgModule({
  declarations: [
    // ваши компоненты
  ],
  imports: [
    BrowserAnimationsModule,
    // другие модули
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }


### Шаг 3: Добавление анимации в компонент

Теперь добавьте анимации в ваш компонент. Например, вы можете использовать trigger, state, style, transition для создания анимации.

import { Component } from '@angular/core';
import { trigger, state, style, transition, animate } from '@angular/animations';

@Component({
  selector: 'app-your-component',
  templateUrl: './your-component.component.html',
  styleUrls: ['./your-component.component.css'],
  animations: [
    trigger('bannerAnimation', [
      state('in', style({ opacity: 1 })),
      state('out', style({ opacity: 0 })),
      transition('in => out', [
        animate('0.5s ease-out')
      ]),
      transition('out => in', [
        animate('0.5s ease-in')
      ]),
    ])
  ]
})
export class YourComponent {
  currentBanner: any; // ваше текущее состояние баннера
  animationState: string = 'in';

  changeBanner(newBanner: any) {
    this.animationState = 'out';
    setTimeout(() => {
      this.currentBanner = newBanner;
      this.animationState = 'in';
    }, 500); // время должно совпадать с длительностью анимации
  }

  // другие методы вашего компонента
}


### Шаг 4: Применение анимации в шаблоне

В вашем шаблоне используйте привязку анимации к баннеру:

<app-popup-container (close)="close()">
  <div class="content-wrapper">
    <div>
      <div [@bannerAnimation]="animationState">
        <app-banner-components-wrapper [setting]="currentBanner"></app-banner-components-wrapper>
      </div>
    </div>
    <div class="icon-wrapper" *ngIf="showIcons()">
      <div *ngIf="isLastBanner()">
        <img (click)="lastBanner()" class="icon-button icon-button--last" src="../../../../assets/img/icons/angles/angle-right.png" alt="Last Banner"/>
      </div>
    </div>
  </div>
</app-popup-container>


### Пояснение:

1. Анимации: Созданы состояния in и out, где in обозначает видимый баннер (полная непрозрачность), а out — исчезающий баннер (нулевая непрозрачность).

2. Метод changeBanner: Этот метод сначала меняет состояние на out, ждет завершения анимации, затем обновляет текущий баннер и возвращает состояние на in.

3. Шаблон: Применение анимации к элементу <div> вокруг app-banner-components-wrapper через привязку [@bannerAnimation]="animationState".

Теперь при изменении текущего баннера будет происходить плавный переход с анимацией.