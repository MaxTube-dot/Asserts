Чтобы осуществить плавный переход высоты элемента с разным содержимым, вы можете использовать CSS-анимации или использовать Angular Animations с изменением свойств высоты. Однако, поскольку изменения высоты могут привести к сложной реализации анимации, лучше будет воспользоваться подходом с max-height.

Вот пример того, как можно осуществить плавный переход высоты с помощью Angular Animations:

### Шаг 1: Определение анимации в компоненте

Необходимо изменить анимацию, чтобы управлять свойством max-height в зависимости от состояния.

import { Component } from '@angular/core';
import { trigger, state, style, transition, animate } from '@angular/animations';

@Component({
  selector: 'app-your-component',
  templateUrl: './your-component.component.html',
  styleUrls: ['./your-component.component.css'],
  animations: [
    trigger('bannerAnimation', [
      state('void', style({
        maxHeight: '0',
        opacity: 0,
        overflow: 'hidden'
      })),
      state('*', style({
        maxHeight: '500px', // Установите значение, соответствующее максимальной высоте вашего контента
        opacity: 1,
        overflow: 'hidden'
      })),
      transition(':enter', [
        animate('0.5s ease-in')
      ]),
      transition(':leave', [
        animate('0.5s ease-out')
      ])
    ])
  ]
})
export class YourComponent {
  currentBanner: any; // ваше текущее состояние баннера
  showBanner: boolean = true;

  changeBanner(newBanner: any) {
    this.showBanner = false;
    setTimeout(() => {
      this.currentBanner = newBanner;
      this.showBanner = true;
    }, 500); // это время должно совпадать с длительностью анимации
  }

  // другие методы вашего компонента
}


### Шаг 2: Обновите ваш шаблон

В шаблоне используйте директиву *ngIf, чтобы управлять отображением app-banner-components-wrapper с анимацией.

<app-popup-container (close)="close()">
  <div class="content-wrapper">
    <div>
      <div *ngIf="showBanner" @bannerAnimation>
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

1. @bannerAnimation: Анимация определяет два состояния: void (когда элемент отсутствует) и * (когда элемент видим). Это состояние контролирует max-height, opacity и overflow.

2. *ngIf="showBanner": Это условие определяет, виден ли элемент. Когда при вызове метода changeBanner устанавливается showBanner = false, элемент сначала исчезает, а затем после задания нового баннера снова отображается.

3. maxHeight: Убедитесь, что значение maxHeight (в этом примере 500px) достаточно велике для вашего содержимого. Это значение можно адаптировать в зависимости от вашего дизайна и возможного контента.

Теперь при изменении содержимого баннера высота будет плавно анимироваться, и изменение не будет резким.