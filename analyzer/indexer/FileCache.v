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

// CachedNamedSymbol описывает закэшированный символ.
// Информация о символе сохраняется в общий индекс, который
// кешируется в памяти.
pub interface CachedNamedSymbol {
	filepath string // путь к файлу, в котором находится символ
	name string // полное имя символа включая модуль
	pos Pos // позиция символа в файле
}

pub struct FunctionCache {
pub:
	filepath string
	name     string
	pos      Pos
}

pub struct StructCache {
pub:
	filepath string
	name     string
	pos      Pos
}

// FileCache описывает кеш одного файла.
// Благодаря разделению кеша на файлы, мы можем индексировать файлы
// параллельно без необходимости синхронизации.
struct FileCache {
pub mut:
	filepath string // абсолютный путь к файлу
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
