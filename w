Если вы хотите, чтобы анимация высоты переходила от текущей высоты к новой, вы можете использовать JavaScript для динамического определения высоты элемента и настройки анимации на этот базис. Вот один из способов достижения желаемого эффекта при помощи Angular:

1. Используйте ViewChild для доступа к элементу. Это позволит вам измерять текущую высоту элемента.

2. Обновите анимацию с учетом предыдущей высоты.

### Шаг 1: Обновите компонент

В этом примере мы будем использовать ViewChild для получения доступа к элементу, а затем производить расчеты высоты.

import { Component, ViewChild, ElementRef } from '@angular/core';
import { trigger, state, style, transition, animate } from '@angular/animations';

@Component({
  selector: 'app-your-component',
  templateUrl: './your-component.component.html',
  styleUrls: ['./your-component.component.css'],
  animations: [
    trigger('bannerAnimation', [
      state('void', style({ maxHeight: '0', opacity: 0, overflow: 'hidden' })),
      state('*', style({ opacity: 1, overflow: 'hidden' })),
      transition(':enter', [
        style({ maxHeight: '0' }),
        animate('0.5s ease-in', style({ maxHeight: '500px', opacity: 1 }))
      ]),
      transition(':leave', [
        animate('0.5s ease-out', style({ maxHeight: '0', opacity: 0 }))
      ])
    ])
  ]
})
export class YourComponent {
  @ViewChild('banner', { static: true }) banner: ElementRef;
  
  currentBanner: any; // Ваше текущее состояние баннера
  showBanner: boolean = true;

  changeBanner(newBanner: any) {
    const bannerElement = this.banner.nativeElement;

    // Текущая высота
    const currentHeight = bannerElement.offsetHeight;

    // Скрыть текущий элемент для измерения его высоты
    this.showBanner = false;

    // Ждем завершения анимации
    setTimeout(() => {
      this.currentBanner = newBanner;
      this.showBanner = true;

      // Устанавливаем высоту обратно, чтобы была анимация к новой высоте
      setTimeout(() => {
        bannerElement.style.maxHeight = bannerElement.scrollHeight + 'px';
      }, 50); // Задержка для перерисовки
    }, 500);  // Это время должно совпадать с длительностью анимации
  }

  // Другие методы вашего компонента
}


### Шаг 2: Обновите шаблон

Обновите ваш HTML для использования #banner в качестве ссылки на элемент:

<app-popup-container (close)="close()">
  <div class="content-wrapper">
    <div>
      <div #banner *ngIf="showBanner" @bannerAnimation>
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


### Пояснения:

1. ViewChild: Используя @ViewChild, мы получаем доступ к DOM-элементу, так что можем измерить его высоту.

2. scrollHeight: Мы измеряем scrollHeight элемента, чтобы получить его фактическую высоту, когда он показывается.

3. setTimeout: Теперь у нас есть два таймера, чтобы сделать анимацию плавной:
   - Первый setTimeout скрывает элемент.
   - Второй setTimeout (с небольшой задержкой) повторно устанавливает высоту max-height, чтобы анимация складывалась плавно.

Этот метод должен обеспечить более плавный переход высоты, который будет соответствовать предыдущему состоянию, а не жестко устанавливать максимальную высоту. Вы можете дополнительно настраивать максимальную высоту в зависимости от вашего содержимого, если это необходимо.