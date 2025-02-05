Чтобы перехватывать вызовы Console.WriteLine в C# и выводить текст в RichTextBox, можно создать собственный класс, который будет обрабатывать вывод. В этом классе необходимо будет переопределить методы для перенаправления вывода.

Вот пример, как это можно сделать:

1. Создайте класс ConsoleRedirect:

using System;
using System.IO;
using System.Text;
using System.Windows.Forms;

public class ConsoleRedirect : TextWriter
{
    private RichTextBox _richTextBox;

    public ConsoleRedirect(RichTextBox richTextBox)
    {
        _richTextBox = richTextBox;
    }

    public override Encoding Encoding => Encoding.UTF8;

    public override void Write(char value)
    {
        _richTextBox.AppendText(value.ToString());
        _richTextBox.ScrollToCaret();
    }

    public override void Write(string value)
    {
        _richTextBox.AppendText(value);
        _richTextBox.ScrollToCaret();
    }

    public override void WriteLine(string value)
    {
        _richTextBox.AppendText(value + Environment.NewLine);
        _richTextBox.ScrollToCaret();
    }
}


2. В вашем основном коде, например, в Form_Load, перенаправьте консольный вывод:

private void Form_Load(object sender, EventArgs e)
{
    Console.SetOut(new ConsoleRedirect(myRichTextBox));
}


Не забудьте заменить myRichTextBox на имя вашего элемента RichTextBox. Теперь все вызовы Console.WriteLine будут автоматически выводиться в RichTextBox. 

С этим подходом вы сможете удобно управлять выводом и выводить текст как в консоль, так и в интерфейс вашего приложения.