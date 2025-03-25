using System;
using System.Text;

public static class StringMasker
{
    public static string MaskSensitiveData(string input)
    {
        if (string.IsNullOrEmpty(input))
            return input;

        var result = new StringBuilder(input.Length);
        var currentWord = new StringBuilder();
        
        for (int i = 0; i < input.Length; i++)
        {
            char c = input[i];
            
            // Если символ буква или цифра — добавляем в текущее слово
            if (char.IsLetterOrDigit(c))
            {
                currentWord.Append(c);
            }
            else
            {
                // Если накопилось слово — маскируем и добавляем в результат
                if (currentWord.Length > 0)
                {
                    result.Append(MaskWord(currentWord.ToString()));
                    currentWord.Clear();
                }
                result.Append(c); // Добавляем не-буквенный символ как есть
            }
        }

        // Обработка последнего слова, если строка заканчивается буквой/цифрой
        if (currentWord.Length > 0)
        {
            result.Append(MaskWord(currentWord.ToString()));
        }

        return result.ToString();
    }

    private static string MaskWord(string word)
    {
        if (word.Length <= 2)
            return word;

        return string.Create(word.Length, word, (chars, state) =>
        {
            chars[0] = state[0];
            chars[^1] = state[^1]; // Последний символ (индекс Length - 1)
            
            for (int i = 1; i < chars.Length - 1; i++)
            {
