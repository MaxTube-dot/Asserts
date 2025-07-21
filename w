using System.Web.Mvc;
using System.Web;

namespace YourApplication.Filters
{
    public class SanitizeInputAttribute : ActionFilterAttribute
    {
        public override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            if (filterContext == null || filterContext.ActionParameters == null)
                return;

            foreach (var parameter in filterContext.ActionParameters)
            {
                if (parameter.Value is string stringValue && !string.IsNullOrEmpty(stringValue))
                {
                    // HTML-кодирование строковых параметров
                    filterContext.ActionParameters[parameter.Key] = HttpUtility.HtmlEncode(stringValue).Trim();
                }
                else if (parameter.Value is string[] stringArray)
                {
                    // Обработка массивов строк
                    for (int i = 0; i < stringArray.Length; i++)
                    {
                        if (!string.IsNullOrEmpty(stringArray[i]))
                        {
                            stringArray[i] = HttpUtility.HtmlEncode(stringArray[i]).Trim();
                        }
                    }
                    filterContext.ActionParameters[parameter.Key] = stringArray;
                }
            }
        }
    }
}