module index

import time
import os
import analyzer.parser
import sync
import runtime
import crypto.md5
import analyzer.psi

// BuiltIndexStatus описывает статус построенного индекса.
pub enum BuiltIndexStatus {
	from_cache // индекс был загружен из кэша
	from_scratch // индекс был построен с нуля
}

// IndexingRoot инкапсулирует в себе логику индексации/реиндексации
// конкретного корня файловой системы.
//
// Разделение на отдельные руты нужно, чтобы обрабатывать стандартную
// библиотеку и пользовательский код раздельно.
[noinit]
pub struct IndexingRoot {
pub:
	root string // корень, который индексируется
pub mut:
	updated_at time.Time // время последнего обновления индекса
	index      Index     // кэш по файлам
	cache_file string    // путь к файлу с кэшем
}

// new_indexing_root создает новый IndexingRoot для переданного пути.
pub fn new_indexing_root(root string) &IndexingRoot {
	cache_file := 'spavn_index_${md5.hexhash(root)}.json'
	return &IndexingRoot{
		root: root
		cache_file: cache_file
	}
}

pub fn (mut i IndexingRoot) load_index() ! {
	now := time.now()
	if !os.exists(i.cache_file) {
		println('Index for "${i.root}" not found, indexing')
		return IndexNotFoundError{}
	}

	data := os.read_file(i.cache_file) or {
		println('Failed to read ${i.cache_file}')
		return IndexNotFoundError{}
	}
	i.index.decode(data) or {
		if err is IndexVersionMismatchError {
			println('Index version mismatch')
		} else {
			println('Error load index ${i.cache_file}: ${err}')
		}
		return NeedReindexedError{}
	}
	println('Loaded index in ${time.since(now)}')
}

pub fn (mut i IndexingRoot) save_index() ! {
	data := i.index.encode()
	os.write_file(i.cache_file, data) or {
		println('Failed to write index.json')
		return err
	}
}

// need_index возвращает true, если файл нужно проиндексировать.
//
// Мы намеренно не индексируем тестовые файлы, чтобы ускорить
// процесс индексирования и поиск по нему.
fn (mut _ IndexingRoot) need_index(path string) bool {
	if path.ends_with('/net/http/mime/db.v') {
		return false
	}
	return path.ends_with('.v') && !path.ends_with('_test.v') && !path.contains('/tests/')
		&& !path.contains('/slow_tests/')
		&& !path.contains('/builtin/wasm/') // TODO: индексировать и эту папку
		&& !path.contains('/builtin/js/') // TODO: индексировать и эту папку
		&& !path.contains('/builtin/linux_bare/') // TODO: индексировать и эту папку
		&& !path.ends_with('.js.v')
}

pub fn (mut i IndexingRoot) index() BuiltIndexStatus {
	now := time.now()
	println('Indexing root ${i.root}')

	if _ := i.load_index() {
		println('Index loaded from cache, took ${time.since(now)}')
		return .from_cache
	}

	file_chan := chan string{cap: 1000}
	cache_chan := chan FileCache{cap: 1000}

	spawn fn [mut i, file_chan] () {
		path := i.root
		os.walk(path, fn [mut i, file_chan] (path string) {
			if i.need_index(path) {
				file_chan <- path
			}
		})

		file_chan.close()
	}()

	spawn i.spawn_indexing_workers(cache_chan, file_chan)

	mut caches := []FileCache{cap: 100}
	for {
		cache := <-cache_chan or { break }
		caches << cache
	}

	for cache in caches {
		i.index.data.data[cache.filepath] = cache
	}

	i.updated_at = time.now()

	println('Indexing finished')
	println('Indexing took ${time.since(now)}')
	return .from_scratch
}

pub fn (mut _ IndexingRoot) index_file(path string) !FileCache {
	last_modified := os.file_last_mod_unix(path)
	content := os.read_file(path)!
	res := parser.parse_code(content)
	psi_file := psi.new_psi_file(path, psi.AstNode(res.tree.root_node()), res.rope)
	cache := FileCache{
		filepath: path
		file_last_modified: last_modified
	}
	mut visitor := &IndexingVisitor{
		filepath: path
		file: psi_file
		cache: &cache
	}
	visitor.process()
	return cache
}

pub fn (mut i IndexingRoot) spawn_indexing_workers(cache_chan chan FileCache, file_chan chan string) {
	mut wg := sync.new_waitgroup()
	workers := runtime.nr_cpus() - 4
	wg.add(workers)
	for j := 0; j < workers; j++ {
		spawn fn [file_chan, mut wg, mut i, cache_chan] () {
			for {
				file := <-file_chan or { break }
				cache_chan <- i.index_file(file) or { println('Error indexing ${file}: ${err}') }
			}

			wg.done()
		}()
	}

	wg.wait()
	cache_chan.close()
}

// ensure_indexed проверяет индекс на актуальность и переиндексирует
// файлы, если они были изменены после последнего индексирования.
pub fn (mut i IndexingRoot) ensure_indexed() {
	now := time.now()
	println('Ensuring indexed root ${i.root}')

	reindex_files_chan := chan string{cap: 1000}
	cache_chan := chan FileCache{cap: 1000}

	spawn fn [reindex_files_chan, mut i] () {
		for filepath, datum in i.index.data.data {
			last_modified := os.file_last_mod_unix(filepath)
			if last_modified > datum.file_last_modified {
				println('File ${filepath} was modified, reindexing')
				i.index.data.data.delete(filepath)
				reindex_files_chan <- filepath
			}
		}

		reindex_files_chan.close()
	}()

	spawn i.spawn_indexing_workers(cache_chan, reindex_files_chan)

	mut caches := []FileCache{cap: 100}
	for {
		cache := <-cache_chan or { break }
		caches << cache
	}

	for cache in caches {
		i.index.data.data[cache.filepath] = cache
	}

	i.index.updated_at = time.now()

	println('Reindexing finished')
	println('Reindexing took ${time.since(now)}')
}