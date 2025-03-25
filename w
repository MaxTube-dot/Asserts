using System;
using System.Linq;
using Newtonsoft.Json.Linq;

public class JsonMasker
{
    public static string MaskJsonValues(string input)
    {
        if (!IsValidJson(input))
        {
            return input; // Возвращаем оригинальную строку, если это не JSON
        }

        try
        {
            var json = JToken.Parse(input);
            MaskJsonTokens(json);
            return json.ToString();
        }
        catch
        {
            return input; // В случае ошибки возвращаем оригинальную строку
        }
    }

    private static bool IsValidJson(string input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return false;
        }

        input = input.Trim();
        return (input.StartsWith("{") && input.EndsWith("}")) || 
               (input.StartsWith("[") && input.EndsWith("]"));
    }

    private static void MaskJsonTokens(JToken token)
    {
        switch (token.Type)
        {
            case JTokenType.Object:
                foreach (var property in ((JObject)token).Properties())
                {
                    MaskJsonTokens(property.Value);
                }
                break;

            case JTokenType.Array:
                foreach (var item in ((JArray)token))
                {
                    MaskJsonTokens(item);
                }
                break;

            case JTokenType.String:
                var strValue = token.Value<string>();
                if (strValue != null && strValue.Length > 1)
                {
                    token.Replace(MaskString(strValue));
                }
                break;

            case JTokenType.Integer:
            case JTokenType.Float:
                var numStr = token.ToString();
                if (numStr.Length > 1)
                {
                    token.Replace(MaskString(numStr));
                }
                break;
        }
    }

    private static string MaskString(string input)
    {
        if (input.Length <= 2)
        {
            return input; // Не маскируем короткие строки
        }

        char firstChar = input[0];
        char lastChar = input[input.Length - 1];
        string maskedPart = new string('*', input.Length - 2);
        return $"{firstChar}{maskedPart}{lastChar}";
    }
}