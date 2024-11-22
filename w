Да, можно разработать алгоритм для оценки схожести строк. Один из самых распространенных способов сделать это — использовать метрики, такие как расстояние Левенштейна или коэффициент Джарка. Они позволяют измерить, насколько две строки похожи друг на друга.

Вот пример на C#, который использует расстояние Левенштейна для определения схожести двух строк:

using System;

class Program
{
    static void Main()
    {
        // Примеры строк для сравнения
        string str1 = "п. Остафьево, район Село Остафьево, д. 3";
        string str2 = "п. Остафьево, район Село Остафьево, д. 4";

        // Вычисление схожести
        double similarity = CalculateSimilarity(str1, str2);
        Console.WriteLine($"Схожесть строк: {similarity * 100:F2}%");
    }

    static double CalculateSimilarity(string str1, string str2)
    {
        int distance = LevenshteinDistance(str1, str2);
        int maxLength = Math.Max(str1.Length, str2.Length);

        // Схожесть в процентах
        return maxLength == 0 ? 1.0 : 1.0 - (double)distance / maxLength;
    }

    static int LevenshteinDistance(string s, string t)
    {
        int n = s.Length;
        int m = t.Length;
        var d = new int[n + 1, m + 1];

        for (int i = 0; i <= n; i++)
            d[i, 0] = i;
        for (int j = 0; j <= m; j++)
            d[0, j] = j;

        for (int i = 1; i <= n; i++)
        {
            for (int j = 1; j <= m; j++)
            {
                int cost = (t[j - 1] == s[i - 1]) ? 0 : 1;
                d[i, j] = Math.Min(Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1), d[i - 1, j - 1] + cost);
            }
        }

        return d[n, m];
    }
}


▎Как работает код:

1. Метод LevenshteinDistance вычисляет расстояние Левенштейна между двумя строками. Это количество операций (вставка, удаление, замена), необходимых для преобразования одной строки в другую.

  
2. Метод CalculateSimilarity использует расстояние Левенштейна для расчета схожести в процентах. Схожесть определяется как отношение длины самой длинной строки к количеству изменений, необходимых для приведения одной строки к другой.

▎Использование:

• Замените str1 и str2 на любые строки, которые вы хотите сравнить.

• Запустите программу, и вы получите процент схожести между строками.

▎Настройка алгоритма:

• Вы можете изменить алгоритм нормализации строк перед сравнением (например, привести к нижнему регистру или удалить лишние пробелы) для повышения точности.

• Также можно использовать другие метрики схожести в зависимости от ваших требований.

Если у вас есть дополнительные вопросы или предложения по улучшению алгоритма, дайте знать!