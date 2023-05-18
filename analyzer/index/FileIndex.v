module index

import analyzer.psi

// FileIndex описывает кеш одного файла.
// Благодаря разделению кеша на файлы, мы можем индексировать файлы
// параллельно без необходимости синхронизации.
struct FileIndex {
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

	stub_list &psi.StubList      [json: '-']
	sink      &psi.StubIndexSink [json: '-']
}
