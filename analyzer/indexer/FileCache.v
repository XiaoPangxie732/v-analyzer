module indexer

// Pos описывает позицию символа в файле.
//
// TODO: хранить два офсета по которым высчитывать позицию
// это позволит сильно уменьшить размер кеша
pub struct Pos {
pub:
	line       int
	column     int
	end_line   int
	end_column int
}

// Visibility описывает видимость символа.

[json_as_number]
pub enum Visibility {
	public // доступен из любого места
	private // доступен только внутри модуля
	global // доступен из любого места, только для глобальных переменных
}

// CachedNamedSymbol описывает закэшированный символ.
// Информация о символе сохраняется в общий индекс, который
// кешируется в памяти.
pub interface CachedNamedSymbol {
	filepath string // путь к файлу, в котором находится символ
	module_fqn string // полное имя модуля, в котором находится символ
	name string // полное имя символа включая модуль
	pos Pos // позиция символа в файле
	visibility Visibility // видимость символа
}

[heap]
pub struct FunctionCache {
pub:
	filepath   string
	module_fqn string
	name       string
	pos        Pos
	visibility Visibility
}

[heap]
pub struct StructCache {
pub:
	filepath   string
	module_fqn string
	name       string
	pos        Pos
	visibility Visibility
}

// FileCache описывает кеш одного файла.
// Благодаря разделению кеша на файлы, мы можем индексировать файлы
// параллельно без необходимости синхронизации.
struct FileCache {
pub mut:
	filepath string // абсолютный путь к файлу
	// file_last_modified хранит время последнего изменения файла
	//
	// Благодаря ему, во время проверки кеша, мы можем понять,
	// был ли изменен файл или нет.
	// Если файл был изменен, то мы переиндексируем файл.
	file_last_modified i64
	// module_name это имя модуля определенное в файле (`module name`),
	// если не определено, то пустая строка
	module_name string
	// module_fqn это полное имя модуля от корня,
	// например, `foo.bar` или `foo.bar.baz`,
	// если модуль не определен, то пустая строка
	module_fqn string
	functions  []FunctionCache
	structs    []StructCache
}