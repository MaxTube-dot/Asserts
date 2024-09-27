Извините за недоразумение. Давайте пересмотрим решение, чтобы правильно учесть высоту текущего элемента во время анимации при переключении содержимого. Это требует некоторого управления состоянием и обеспечения анимации, привязанной к высоте текущего содержимого. 

### Шаг 1: Настройка компонента

Мы будем использовать ElementRef для измерения высоты содержимого и добавлять логику, чтобы анимация работала именно правильно.

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
        style({ maxHeight: '0', opacity: 0 }),
        animate('0.5s ease-in', style({ maxHeight: '1000px', opacity: 1 })) // Используйте максимальную высоту или установите правильное значение
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

  constructor() {
    this.currentBanner = {}; // Инициализация вашего баннера
  }

  changeBanner(newBanner: any) {
    // Получаем ссылку на элемент
    const bannerElement = this.banner.nativeElement;
    
    // Получаем текущую высоту
    const currentHeight = bannerElement.offsetHeight;

    // Скрываем текущий элемент
    this.showBanner = false;

    // Ждем завершения анимации
    setTimeout(() => {
      this.currentBanner = newBanner;
      this.showBanner = true;

      // Правильная анимация на основе текущей высоты
      setTimeout(() => {
        const newHeight = bannerElement.scrollHeight; // Высота нового содержимого

        bannerElement.style.maxHeight = `${newHeight}px`; // Устанавливаем maxHeight
      }, 50); // Для перерисовки после изменения состояния
    }, 500);  // Это время должно совпадать с длительностью анимации
  }
}


### Шаг 2: Обновите шаблон

Убедитесь, что вы используете правильные ссылки на элемент в шаблоне:

<app-popup-container (close)="close()">
  <div class="content-wrapper">
    <div #banner *ngIf="showBanner" @bannerAnimation>
      <app-banner-components-wrapper [setting]="currentBanner"></app-banner-components-wrapper>
    </div>
    <div class="icon-wrapper" *ngIf="showIcons()">
      <div *ngIf="isLastBanner()">
        <img (click)="lastBanner()" class="icon-button icon-button--last" src="../../../../assets/img/icons/angles/angle-right.png" alt="Last Banner"/>
      </div>
    </div>
  </div>
</app-popup-container>


### Пояснение:

1. Измерение высоты: Используя scrollHeight, мы получаем фактическую высоту нового содержимого, и устанавливаем maxHeight на эту величину. Это важно, так как браузер не известен о содержимом заранее.

2. Управление состоянием: Мы используем флаг showBanner для управления показом элемента во время анимации.

3. Анимация: Мы используем CSS анимации для плавного скрытия и появления содержимого.

### Примечания:

- Убедитесь, что значение maxHeight в анимации не превышает максимальную возможную высоту, чтобы избежать неожиданного поведения.
  
- Если вы хотите, чтобы высота была более адаптивной, можно рассмотреть настройки maxHeight в зависимости от фактического контента, чтобы избежать жесткости.

Попробуйте это решение, и если у вас все еще возникают проблемы, дайте знать, и мы найдем способ их устранить!