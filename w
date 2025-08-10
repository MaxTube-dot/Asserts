using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.Text;
using System.Collections.Immutable;
using System.Text;

namespace BlazorComponentsGenerator;

[Generator]
public class BlazorComponentsIncrementalGenerator : IIncrementalGenerator
{
    public void Initialize(IncrementalGeneratorInitializationContext context)
    {
        // Шаг 1: Фильтрация классов, наследующих DbContext
        var dbContextProvider = context.SyntaxProvider
            .CreateSyntaxProvider(
                predicate: static (node, _) => IsDbContextClass(node),
                transform: static (ctx, _) => GetDbContextClass(ctx))
            .Where(static c => c is not null);

        // Шаг 2: Комбинация с компиляцией
        var compilationAndDbContexts = context.CompilationProvider.Combine(dbContextProvider.Collect());

        // Шаг 3: Генерация кода
        context.RegisterSourceOutput(compilationAndDbContexts, 
            static (spc, source) => Execute(source.Left, source.Right, spc));
    }

    private static bool IsDbContextClass(SyntaxNode node)
    {
        return node is ClassDeclarationSyntax classDecl && 
               classDecl.BaseList?.Types.Any(t => t.Type.ToString().Contains("DbContext")) == true;
    }

    private static ClassDeclarationSyntax? GetDbContextClass(GeneratorSyntaxContext context)
    {
        return context.Node as ClassDeclarationSyntax;
    }

    private static void Execute(Compilation compilation, 
                              ImmutableArray<ClassDeclarationSyntax> dbContextClasses,
                              SourceProductionContext context)
    {
        if (dbContextClasses.IsDefaultOrEmpty)
            return;

        foreach (var dbContextClass in dbContextClasses)
        {
            var model = compilation.GetSemanticModel(dbContextClass.SyntaxTree);
            var dbContextSymbol = model.GetDeclaredSymbol(dbContextClass) as INamedTypeSymbol;
            
            if (dbContextSymbol == null) 
                continue;

            var generateAttr = dbContextSymbol.GetAttributes()
                .FirstOrDefault(a => a.AttributeClass?.Name == "GenerateBlazorComponentsAttribute");

            var generateCRUD = generateAttr?.NamedArguments
                .FirstOrDefault(a => a.Key == "GenerateCRUD").Value.Value as bool? ?? true;

            var routePrefix = generateAttr?.NamedArguments
                .FirstOrDefault(a => a.Key == "RoutePrefix").Value.Value as string ?? "data";

            var dbSets = GetDbSetProperties(dbContextSymbol);

            foreach (var dbSet in dbSets)
            {
                var entityType = GetEntityType(dbSet.Type);
                if (entityType == null) 
                    continue;

                GenerateListComponent(context, entityType, routePrefix);
                
                if (generateCRUD)
                {
                    GenerateEditComponent(context, entityType, routePrefix);
                }
            }
        }
    }

    // Остальные методы (GetDbSetProperties, GetEntityType, GenerateListComponent, GenerateEditComponent) 
    // остаются такими же как в предыдущей реализации
}