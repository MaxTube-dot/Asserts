<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Таблица с иконкой и описанием</title>
    <style>
        table {
            width: 100%;
            border-collapse: collapse;
        }

        td {
            vertical-align: middle;
            padding: 10px;
        }

        .icon {
            width: 100px; /* Установите ширину иконки */
            height: 100px; /* Установите высоту иконки */
        }

        .description {
            text-align: left;
            line-height: 1.5em; /* Равномерное расстояние между строками */
        }

        .line {
            margin: 5px 0; /* Отступы между строками */
        }
    </style>
</head>
<body>

<table>
    <tr>
        <td rowspan="3">
            <img src="path_to_your_icon.png" alt="Иконка" class="icon">
        </td>
        <td class="description">
            <div class="line">Первое слово</div>
        </td>
    </tr>
    <tr>
        <td class="description">
            <div class="line">Второе слово</div>
        </td>
    </tr>
    <tr>
        <td class="description">
            <div class="line">Третье слово</div>
        </td>
    </tr>
</table>

</body>
</html>