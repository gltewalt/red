Red/System [
	Title:	"Simple file IO functions (temporary)"
	Author: "Nenad Rakocevic"
	File: 	%simple-io.reds
	Tabs: 	4
	Rights: "Copyright (C) 2012-2015 Nenad Rakocevic. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#enum http-verb! [
	HTTP_GET
	HTTP_PUT
	HTTP_POST
	HTTP_DEL
	HTTP_HEAD
]

simple-io: context [

	#enum red-io-mode! [
		RIO_READ:	1
		RIO_WRITE:	2
		RIO_APPEND:	4
		RIO_SEEK:	8
		RIO_NEW:	16
	]

	#either OS = 'Windows [

		#define GENERIC_WRITE			40000000h
		#define GENERIC_READ 			80000000h
		#define FILE_SHARE_READ			00000001h
		#define FILE_SHARE_WRITE		00000002h
		#define OPEN_ALWAYS				00000004h
		#define OPEN_EXISTING			00000003h
		#define CREATE_ALWAYS			00000002h
		#define FILE_ATTRIBUTE_NORMAL	00000080h
		#define FILE_ATTRIBUTE_DIRECTORY 00000010h

		#define SET_FILE_BEGIN			0
		#define SET_FILE_CURRENT		1
		#define SET_FILE_END			2

		#define MAX_FILE_REQ_BUF		4000h			;-- 16 KB
		#define OFN_HIDEREADONLY		0004h
		#define OFN_EXPLORER			00080000h
		#define OFN_ALLOWMULTISELECT	00000200h

		#define WIN32_FIND_DATA_SIZE	592

		WIN32_FIND_DATA: alias struct! [
			dwFileAttributes	[integer!]
			ftCreationTime		[float!]
			ftLastAccessTime	[float!]
			ftLastWriteTime		[float!]
			nFileSizeHigh		[integer!]
			nFileSizeLow		[integer!]
			dwReserved0			[integer!]
			dwReserved1			[integer!]
			;cFileName			[byte-ptr!]				;-- WCHAR  cFileName[ 260 ]
			;cAlternateFileName	[c-string!]				;-- cAlternateFileName[ 14 ]
		]

		tagOFNW: alias struct! [
			lStructSize			[integer!]
			hwndOwner			[integer!]
			hInstance			[integer!]
			lpstrFilter			[c-string!]
			lpstrCustomFilter	[c-string!]
			nMaxCustFilter		[integer!]
			nFilterIndex		[integer!]
			lpstrFile			[byte-ptr!]
			nMaxFile			[integer!]
			lpstrFileTitle		[c-string!]
			nMaxFileTitle		[integer!]
			lpstrInitialDir		[c-string!]
			lpstrTitle			[c-string!]
			Flags				[integer!]
			nFileOffset			[integer!]
			;nFileExtension		[integer!]
			lpstrDefExt			[c-string!]
			lCustData			[integer!]
			lpfnHook			[integer!]
			lpTemplateName		[integer!]
			;-- if (_WIN32_WINNT >= 0x0500)
			pvReserved			[integer!]
			dwReserved			[integer!]
			FlagsEx				[integer!]
		]
	
		#import [
			"kernel32.dll" stdcall [
				CreateFileA: "CreateFileA" [			;-- temporary needed by Red/System
					filename	[c-string!]
					access		[integer!]
					share		[integer!]
					security	[int-ptr!]
					disposition	[integer!]
					flags		[integer!]
					template	[int-ptr!]
					return:		[integer!]
				]
				CreateFileW: "CreateFileW" [
					filename	[c-string!]
					access		[integer!]
					share		[integer!]
					security	[int-ptr!]
					disposition	[integer!]
					flags		[integer!]
					template	[int-ptr!]
					return:		[integer!]
				]
				ReadFile:	"ReadFile" [
					file		[integer!]
					buffer		[byte-ptr!]
					bytes		[integer!]
					read		[int-ptr!]
					overlapped	[int-ptr!]
					return:		[integer!]
				]
				WriteFile:	"WriteFile" [
					file		[integer!]
					buffer		[byte-ptr!]
					bytes		[integer!]
					written		[int-ptr!]
					overlapped	[int-ptr!]
					return:		[integer!]
				]
				FindFirstFile: "FindFirstFileW" [
					filename	[c-string!]
					filedata	[WIN32_FIND_DATA]
					return:		[integer!]
				]
				FindNextFile: "FindNextFileW" [
					file		[integer!]
					filedata	[WIN32_FIND_DATA]
					return:		[integer!]
				]
				FindClose: "FindClose" [
					file		[integer!]
					return:		[integer!]
				]
				GetFileSize: "GetFileSize" [
					file		[integer!]
					high-size	[integer!]
					return:		[integer!]
				]
				CloseHandle:	"CloseHandle" [
					obj			[integer!]
					return:		[integer!]
				]
				SetFilePointer: "SetFilePointer" [
					file		[integer!]
					distance	[integer!]
					pDistance	[int-ptr!]
					dwMove		[integer!]
					return:		[integer!]
				]
				SetEndOfFile: "SetEndOfFile" [
					file		[integer!]
					return:		[integer!]
				]
				lstrlen: "lstrlenW" [
					str			[byte-ptr!]
					return:		[integer!]
				]
			]
			"comdlg32.dll" stdcall [
				GetOpenFileName: "GetOpenFileNameW" [
					lpofn		[tagOFNW]
					return:		[integer!]
				]
				GetSaveFileName: "GetSaveFileNameW" [
					lpofn		[tagOFNW]
					return:		[integer!]
				]
			]
		]
	][
		#define O_RDONLY	0
		#define O_WRONLY	1
		#define O_RDWR		2
		#define O_BINARY	0

		#define S_IREAD		256
		#define S_IWRITE    128
		#define S_IRGRP		32
		#define S_IWGRP		16
		#define S_IROTH		4

		#define	DT_DIR		#"^(04)"

		#case [
			any [OS = 'FreeBSD OS = 'MacOSX] [
				#define O_CREAT		0200h
				#define O_APPEND	8
			]
			true [
				#define O_CREAT		64
				#define O_APPEND	1024
			]
		]

		#case [
			OS = 'FreeBSD [
				;-- http://fxr.watson.org/fxr/source/sys/stat.h?v=FREEBSD10
				stat!: alias struct! [
					st_dev		[integer!]
					st_ino		[integer!]
					st_modelink	[integer!]					;-- st_mode & st_link are both 16bit fields
					st_uid		[integer!]
					st_gid		[integer!]
					st_rdev		[integer!]
					atv_sec		[integer!]					;-- struct timespec inlined
					atv_msec	[integer!]
					mtv_sec		[integer!]					;-- struct timespec inlined
					mtv_msec	[integer!]
					ctv_sec		[integer!]					;-- struct timespec inlined
					ctv_msec	[integer!]
					st_size		[integer!]
					st_size_h	[integer!]
					st_blocks_l	[integer!]
					st_blocks_h	[integer!]
					st_blksize	[integer!]
					st_flags	[integer!]
					st_gen		[integer!]
					st_lspare	[integer!]
					btm_sec     [integer!]
					btm_msec    [integer!]                  ;-- struct timespec inlined
					pad0		[integer!]
					pad1		[integer!]
				]
				#define DIRENT_NAME_OFFSET 8
				dirent!: alias struct! [					;@@ the same as MacOSX
					d_ino		[integer!]
					d_reclen	[byte!]
					_d_reclen_	[byte!]
					d_type		[byte!]
					d_namlen	[byte!]
					;d_name		[byte! [256]]
				]
			]
			OS = 'MacOSX [
				stat!: alias struct! [
					st_dev		[integer!]
					st_ino		[integer!]
					st_modelink	[integer!]					;-- st_mode & st_link are both 16bit fields
					st_uid		[integer!]
					st_gid		[integer!]
					st_rdev		[integer!]
					atv_sec		[integer!]					;-- struct timespec inlined
					atv_msec	[integer!]
					mtv_sec		[integer!]					;-- struct timespec inlined
					mtv_msec	[integer!]
					ctv_sec		[integer!]					;-- struct timespec inlined
					ctv_msec	[integer!]
					st_size		[integer!]
					st_blocks	[integer!]
					st_blksize	[integer!]
					st_flags	[integer!]
					st_gen		[integer!]
				]
				;;-- #if __DARWIN_64_BIT_INO_T
				;#define DIRENT_NAME_OFFSET	21
				;dirent!: alias struct! [
				;	d_ino		[integer!]
				;	_d_ino_		[integer!]
				;	d_seekoff	[integer!]
				;	_d_seekoff_	[integer!]
				;	d_reclen	[integer!]					;-- d_reclen & d_namlen
				;	;d_namlen	[integer!]
				;	d_type		[byte!]
				;	;d_name		[byte! [1024]]
				;]
				;;-- #endif

				#define DIRENT_NAME_OFFSET 8
				dirent!: alias struct! [
					d_ino		[integer!]
					d_reclen	[byte!]
					_d_reclen_	[byte!]
					d_type		[byte!]
					d_namlen	[byte!]
					;d_name		[byte! [256]]
				]
			]
			OS = 'Syllable [
				;-- http://glibc.sourcearchive.com/documentation/2.7-18lenny7/glibc-2_87_2bits_2stat_8h_source.html
				stat!: alias struct! [
					st_mode		[integer!]
					st_ino		[integer!]
					st_dev		[integer!]
					st_nlink	[integer!]
					st_uid		[integer!]
					st_gid		[integer!]
					filler1		[integer!]				;-- not in spec above...
					filler2		[integer!]				;-- not in spec above...
					st_size		[integer!]
					;...incomplete...
				]
				#define DIRENT_NAME_OFFSET 8
				dirent!: alias struct! [
					d_ino		[integer!]
					d_reclen	[byte!]
					_d_reclen_	[byte!]
					d_type		[byte!]
					d_namlen	[byte!]
					;d_name		[byte! [256]]
				]
			]
			all [legacy find legacy 'stat32] [
				stat!: alias struct! [
					st_dev		[integer!]
					st_ino		[integer!]
					st_mode		[integer!]
					st_nlink	[integer!]
					st_uid		[integer!]
					st_gid		[integer!]
					st_rdev		[integer!]
					st_size		[integer!]
					st_blksize	[integer!]
					st_blocks	[integer!]
					st_atime	[integer!]
					st_mtime	[integer!]
					st_ctime	[integer!]
				]
				#define DIRENT_NAME_OFFSET 8
				dirent!: alias struct! [
					d_ino		[integer!]
					d_reclen	[byte!]
					_d_reclen_	[byte!]
					d_type		[byte!]
					d_namlen	[byte!]
					;d_name		[byte! [256]]
				]
			]
			OS = 'Android [ ; else
				;https://android.googlesource.com/platform/bionic.git/+/master/libc/include/sys/stat.h
				stat!: alias struct! [				;-- stat64 struct
					st_dev_h	  [integer!]
					st_dev_l	  [integer!]
					pad0		  [integer!]
					__st_ino	  [integer!]
					st_mode		  [integer!]
					st_nlink	  [integer!]
					st_uid		  [integer!]
					st_gid		  [integer!]
					st_rdev_h	  [integer!]
					st_rdev_l	  [integer!]
					pad1		  [integer!]
					st_size_h	  [integer!]
					st_size	  [integer!]
					st_blksize	  [integer!]
					st_blocks_h	  [integer!]
					st_blocks	  [integer!]
					st_atime	  [integer!]
					st_atime_nsec [integer!]
					st_mtime	  [integer!]
					st_mtime_nsec [integer!]
					st_ctime	  [integer!]
					st_ctime_nsec [integer!]
					st_ino_h	  [integer!]
					st_ino_l	  [integer!]
					;...optional padding skipped
				]
				#define DIRENT_NAME_OFFSET	19
				dirent!: alias struct! [
					d_ino		[integer!]
					_d_ino_		[integer!]
					d_off		[integer!]
					_d_off_		[integer!]
					d_reclen	[byte!]
					_d_reclen_	[byte!]
					d_type		[byte!]
					;d_name		[byte! [256]]
				]
			]
			true [ ; else
				;-- http://lxr.free-electrons.com/source/arch/x86/include/uapi/asm/stat.h
				stat!: alias struct! [				;-- stat64 struct
					st_dev_l	  [integer!]
					st_dev_h	  [integer!]
					pad0		  [integer!]
					__st_ino	  [integer!]
					st_mode		  [integer!]
					st_nlink	  [integer!]
					st_uid		  [integer!]
					st_gid		  [integer!]
					st_rdev_l	  [integer!]
					st_rdev_h	  [integer!]
					pad1		  [integer!]
					st_size		  [integer!]
					st_blksize	  [integer!]
					st_blocks	  [integer!]
					st_atime	  [integer!]
					st_atime_nsec [integer!]
					st_mtime	  [integer!]
					st_mtime_nsec [integer!]
					st_ctime	  [integer!]
					st_ctime_nsec [integer!]
					st_ino_h	  [integer!]
					st_ino_l	  [integer!]
					;...optional padding skipped
				]

				#define DIRENT_NAME_OFFSET 11
				dirent!: alias struct! [
					d_ino			[integer!]
					d_off			[integer!]
					d_reclen		[byte!]
					d_reclen_pad	[byte!]
					d_type			[byte!]
					;d_name			[byte! [256]]
				]
			]
		]

		#case [
			any [OS = 'MacOSX OS = 'FreeBSD OS = 'Android] [
				#import [
					LIBC-file cdecl [
						;-- https://developer.apple.com/library/mac/documentation/Darwin/Reference/ManPages/10.6/man2/stat.2.html?useVersion=10.6
						_stat:	"fstat" [
							file		[integer!]
							restrict	[stat!]
							return:		[integer!]
						]
					]
				]
			]
			true [
				#import [
					LIBC-file cdecl [
						;-- http://refspecs.linuxbase.org/LSB_3.0.0/LSB-Core-generic/LSB-Core-generic/baselib-xstat-1.html
						_stat:	"__fxstat" [
							version		[integer!]
							file		[integer!]
							restrict	[stat!]
							return:		[integer!]
						]
					]
				]
			]

		]

		#import [
			LIBC-file cdecl [
				_open:	"open" [
					filename	[c-string!]
					flags		[integer!]
					mode		[integer!]
					return:		[integer!]
				]
				_read:	"read" [
					file		[integer!]
					buffer		[byte-ptr!]
					bytes		[integer!]
					return:		[integer!]
				]
				_write:	"write" [
					file		[integer!]
					buffer		[byte-ptr!]
					bytes		[integer!]
					return:		[integer!]
				]
				_close:	"close" [
					file		[integer!]
					return:		[integer!]
				]
				opendir: "opendir" [
					filename	[c-string!]
					return:		[integer!]
				]
				readdir: "readdir" [
					file		[integer!]
					return:		[dirent!]
				]
				closedir: "closedir" [
					file		[integer!]
					return:		[integer!]
				]
			]
		]
	]
	
	open-file: func [
		filename [c-string!]
		mode	 [integer!]
		unicode? [logic!]
		return:	 [integer!]
		/local
			file   [integer!]
			modes  [integer!]
			access [integer!]
	][
		#either OS = 'Windows [
			either mode and RIO_READ <> 0 [
				modes: GENERIC_READ
				access: OPEN_EXISTING
			][
				modes: GENERIC_WRITE
				either mode and RIO_APPEND <> 0 [
					access: OPEN_ALWAYS
				][
					access: CREATE_ALWAYS
				]
			]
			either unicode? [
				file: CreateFileW
					filename
					modes
					FILE_SHARE_READ or FILE_SHARE_WRITE
					null
					access
					FILE_ATTRIBUTE_NORMAL
					null
			][
				file: CreateFileA
					filename
					modes
					FILE_SHARE_READ or FILE_SHARE_WRITE
					null
					access
					FILE_ATTRIBUTE_NORMAL
					null
			]
		][
			either mode and RIO_READ <> 0 [
				modes: O_BINARY or O_RDONLY
				access: S_IREAD
			][
				modes: O_BINARY or O_WRONLY or O_CREAT
				if mode and RIO_APPEND <> 0 [modes: modes or O_APPEND]
				access: S_IREAD or S_IWRITE or S_IRGRP or S_IWGRP or S_IROTH
			]
			file: _open filename modes access
		]
		if file = -1 [return -1]
		file
	]
	
	file-size?: func [
		file	 [integer!]
		return:	 [integer!]
		/local s
	][
		#case [
			OS = 'Windows [
				GetFileSize file null
			]
			any [OS = 'MacOSX OS = 'FreeBSD OS = 'Android] [
				s: declare stat!
				_stat file s
				s/st_size
			]
			true [ ; else
				s: declare stat!
				_stat 3 file s
				s/st_size
			]
		]
	]
	
	read-buffer: func [
		file	[integer!]
		buffer	[byte-ptr!]
		size	[integer!]
		return:	[integer!]
		/local
			read-sz [integer!]
			res		[integer!]
	][
		#either OS = 'Windows [
			read-sz: -1
			res: ReadFile file buffer size :read-sz null
			res: either zero? res [-1][1]
		][
			res: _read file buffer size
		]
		res
	]
	
	close-file: func [
		file	[integer!]
		return:	[integer!]
	][
		#either OS = 'Windows [
			CloseHandle file
		][
			_close file
		]
	]

	to-OS-path: func [
		src		[red-file!]
		return: [c-string!]
		/local
			str [red-string!]
			len [integer!]
	][
		str: string/rs-make-at stack/push* string/rs-length? as red-string! src
		file/to-local-path src str no
		#either OS = 'Windows [
			unicode/to-utf16 str
		][
			len: -1
			unicode/to-utf8 str :len
		]
	]

	read-file: func [
		filename [c-string!]
		binary?	 [logic!]
		unicode? [logic!]
		return:	 [red-value!]
		/local
			buffer	[byte-ptr!]
			file	[integer!]
			size	[integer!]
			val		[red-value!]
			str		[red-string!]
			len		[integer!]
	][
		unless unicode? [		;-- only command line args need to be checked
			if filename/1 = #"^"" [filename: filename + 1]	;-- FIX: issue #1234
			len: length? filename
			if filename/len = #"^"" [filename/len: null-byte]
		]
		file: open-file filename RIO_READ unicode?
		if file < 0 [return none-value]

		size: file-size? file

		if size <= 0 [
			print-line "*** Warning: empty file"
		]
		
		buffer: allocate size
		len: read-buffer file buffer size
		close-file file

		if negative? len [return none-value]

		val: as red-value! either binary? [
			binary/load buffer size
		][
			str: as red-string! stack/push*
			str/header: TYPE_STRING							;-- implicit reset of all header flags
			str/head: 0
			str/node: unicode/load-utf8-buffer as-c-string buffer size null null yes
			str/cache: either size < 64 [as-c-string buffer][null]			;-- cache only small strings
			str
		]
		free buffer
		val
	]

	write-file: func [
		filename [c-string!]
		data	 [byte-ptr!]
		size	 [integer!]
		binary?	 [logic!]
		append?  [logic!]
		unicode? [logic!]
		return:	 [integer!]
		/local
			file	[integer!]
			len		[integer!]
			mode	[integer!]
			ret		[integer!]
	][
		unless unicode? [		;-- only command line args need to be checked
			if filename/1 = #"^"" [filename: filename + 1]	;-- FIX: issue #1234
			len: length? filename
			if filename/len = #"^"" [filename/len: null-byte]
		]
		mode: RIO_WRITE
		if append? [mode: mode or RIO_APPEND]
		file: open-file filename mode unicode?
		if file < 0 [return file]

		#either OS = 'Windows [
			len: 0
			if append? [SetFilePointer file 0 null SET_FILE_END]
			ret: WriteFile file data size :len null
			ret: either zero? ret [-1][1]
		][
			ret: _write file data size
		]
		close-file file
		ret
	]

	dir?: func [
		filename [red-file!]
		return:  [logic!]
		/local
			len  [integer!]
			cp	 [integer!]
	][
		len: string/rs-abs-length? as red-string! filename
		cp: string/rs-abs-at as red-string! filename len - 1
		either any [
			cp = as-integer #"/"
			cp = as-integer #"\"
		][true][false]
	]

	read-dir: func [
		filename	[red-file!]
		return:		[red-block!]
		/local
			info
			name	[byte-ptr!]
			handle	[integer!]
			blk		[red-block!]
			str		[red-string!]
			len		[integer!]
			s		[series!]
	][
		#either OS = 'Windows [
			s: string/append-char GET_BUFFER(filename) as-integer #"*"

			info: as WIN32_FIND_DATA allocate WIN32_FIND_DATA_SIZE
			handle: FindFirstFile to-OS-path filename info
			s/tail: as cell! (as byte-ptr! s/tail) - GET_UNIT(s)

			if handle = -1 [fire [TO_ERROR(access cannot-open) filename]]

			blk: block/push-only* 1
			name: (as byte-ptr! info) + 44
			until [
				unless any [		;-- skip over the . and .. dir case
					name = null
					all [
						(string/get-char name UCS-2) = as-integer #"."
						any [
							zero? string/get-char name + 2 UCS-2
							all [
								(string/get-char name + 2 UCS-2) = as-integer #"."
								zero? string/get-char name + 4 UCS-2
							]
						]
					]
				][
					str: string/load-in as-c-string name lstrlen name blk UTF-16LE
					if info/dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <> 0 [
						string/append-char GET_BUFFER(str) as-integer #"/"
					]
					set-type as red-value! str TYPE_FILE
				]
				zero? FindNextFile handle info
			]
			FindClose handle
			free as byte-ptr! info
			blk
		][
			handle: opendir to-OS-path filename
			if zero? handle [fire [TO_ERROR(access cannot-open) filename]]
			blk: block/push-only* 1
			while [
				info: readdir handle
				info <> null
			][
				name: (as byte-ptr! info) + DIRENT_NAME_OFFSET
				unless any [		;-- skip over the . and .. dir case
					name = null
					all [
						name/1 = #"."
						any [
							name/2 = #"^@"
							all [name/2 = #"." name/3 = #"^@"]
						]
					]
				][
					#either OS = 'MacOSX [
						len: as-integer info/d_namlen
					][
						len: length? as-c-string name
					]
					str: string/load-in as-c-string name len blk UTF-8
					if info/d_type = DT_DIR [
						string/append-char GET_BUFFER(str) as-integer #"/"
					]
					set-type as red-value! str TYPE_FILE
				]
			]
			closedir handle
			blk
		]
	]

	read: func [
		filename [red-file!]
		binary?	 [logic!]
		return:	 [red-value!]
		/local
			data [red-value!]
	][
		if dir? filename [
			return as red-value! read-dir filename
		]

		data: read-file to-OS-path filename binary? yes
		if TYPE_OF(data) = TYPE_NONE [
			fire [TO_ERROR(access cannot-open) filename]
		]
		data
	]

	write: func [
		filename [red-file!]
		data	 [red-value!]
		part	 [red-value!]
		binary?	 [logic!]
		append?  [logic!]
		return:  [integer!]
		/local
			len  	[integer!]
			str  	[red-string!]
			buf  	[byte-ptr!]
			int  	[red-integer!]
			limit	[integer!]
			type	[integer!]
	][
		limit: -1
		if OPTION?(part) [
			either TYPE_OF(part) = TYPE_INTEGER [
				int: as red-integer! part
				if negative? int/value [return -1]			;-- early exit if part <= 0
				limit: int/value
			][
				ERR_INVALID_REFINEMENT_ARG(refinements/_part part)
			]
		]
		type: TYPE_OF(data)
		case [
			type = TYPE_STRING [
				len: limit
				str: as red-string! data
				buf: as byte-ptr! unicode/io-to-utf8 str :len not binary?
			]
			type = TYPE_BINARY [
				buf: binary/rs-head as red-binary! data
				len: binary/rs-length? as red-binary! data
				if all [limit > 0 len > limit][len: limit]
			]
			true [ERR_EXPECT_ARGUMENT(type 1)]
		]
		type: write-file to-OS-path filename buf len binary? append? yes
		if negative? type [
			fire [TO_ERROR(access cannot-open) filename]
		]
		type
	]

	file-filter-to-str: func [
		filter	[red-block!]
		return: [c-string!]
		/local
			s	[series!]
			val [red-value!]
			end [red-value!]
			str [red-string!]
	][
		s: GET_BUFFER(filter)
		val: s/offset + filter/head
		end:  s/tail
		if val = end [return null]

		str: string/make-at stack/push* 16 UCS-2
		while [val < end][
			string/concatenate str as red-string! val -1 0 yes no
			string/append-char GET_BUFFER(str) 0
			val: val + 1
		]
		unicode/to-utf16 str
	]

	file-list-to-block: func [
		buffer	[byte-ptr!]
		return: [red-block!]
		/local
			blk [red-block!]
	][
		blk: block/push-only* 1
		blk
	]

	request-file: func [
		title	[red-string!]
		file	[red-value!]
		filter	[red-block!]
		save?	[logic!]
		multi?	[logic!]
		return: [red-value!]
		/local
			filters [c-string!]
			buffer	[byte-ptr!]
			ret		[integer!]
			files	[red-value!]
			base	[red-value!]
			str		[red-string!]
			pbuf	[byte-ptr!]
			ofn
	][
		#either OS = 'Windows [
			base: stack/arguments
			filters: #u16 "All files^@*.*^@Red scripts^@*.red;*.reds^@REBOL scripts^@*.r^@Text files^@*.txt^@"
			buffer: allocate MAX_FILE_REQ_BUF
			either file >= base [
				pbuf: as byte-ptr! unicode/to-utf16 as red-string! file
				copy-memory buffer pbuf (lstrlen pbuf) << 1 + 2
			][
				buffer/1: #"^@"
				buffer/2: #"^@"
			]

			ofn: declare tagOFNW
			ofn/lStructSize: size? tagOFNW
			;ofn/hwndOwner: how to set it?
			ofn/lpstrTitle: either title >= base [unicode/to-utf16 title][null]
			;ofn/lpstrInitialDir
			ofn/lpstrFile: buffer
			ofn/lpstrFilter: either filter >= base [file-filter-to-str filter][filters]
			ofn/nMaxFile: MAX_FILE_REQ_BUF
			ofn/lpstrFileTitle: null
			ofn/nMaxFileTitle: 0

			ofn/Flags: OFN_HIDEREADONLY or OFN_EXPLORER
			if multi? [ofn/Flags: ofn/Flags or OFN_ALLOWMULTISELECT]

			ret: either save? [GetSaveFileName ofn][GetOpenFileName ofn]
			files: as red-value! either zero? ret [none-value][
				as red-value! either multi? [
					file-list-to-block buffer
				][
					str: string/load as-c-string buffer lstrlen buffer UTF-16LE
					#call [to-red-file str]
					stack/arguments
				]
			]
			free buffer
			files
		][
			as red-value! none-value
		]
	]

	#switch OS [
		Windows [
			request-http: func [
				method	[integer!]
				url		[red-url!]
				header	[red-block!]
				data	[red-value!]
				binary? [logic!]
				return: [red-value!]
				/local
					action	[c-string!]
					hr 		[integer!]
					clsid	[tagGUID]
					async 	[tagVARIANT]
					body 	[tagVARIANT]
					IH		[interface!]
					http	[IWinHttpRequest]
					bstr-d	[byte-ptr!]
					bstr-m	[byte-ptr!]
					bstr-u	[byte-ptr!]
					buf-ptr [integer!]
					s		[series!]
					value	[red-value!]
					tail	[red-value!]
					l-bound [integer!]
					u-bound [integer!]
					array	[integer!]
					res		[red-value!]
					len		[integer!]
			][
				res: as red-value! none-value
				clsid: declare tagGUID
				async: declare tagVARIANT
				body:  declare tagVARIANT
				VariantInit async
				VariantInit body
				async/data1: VT_BOOL
				async/data3: 0					;-- VARIANT_FALSE

				switch method [
					HTTP_GET [
						action: #u16 "GET"
						body/data1: VT_ERROR
					]
					HTTP_PUT [
						action: #u16 "PUT"
						--NOT_IMPLEMENTED--
					]
					HTTP_POST [
						action: #u16 "POST"
						body/data1: VT_BSTR
						bstr-d: SysAllocString unicode/to-utf16 as red-string! data
						body/data3: as-integer bstr-d
					]
					default [--NOT_IMPLEMENTED--]
				]

				IH: declare interface!
				http: null

				hr: CLSIDFromProgID #u16 "WinHttp.WinHttpRequest.5.1" clsid

				if hr >= 0 [
					hr: CoCreateInstance as int-ptr! clsid 0 CLSCTX_INPROC_SERVER IID_IWinHttpRequest IH
				]

				if hr >= 0 [
					http: as IWinHttpRequest IH/ptr/vtbl
					bstr-m: SysAllocString action
					bstr-u: SysAllocString unicode/to-utf16 as red-string! url
					hr: http/Open IH/ptr bstr-m bstr-u async/data1 async/data2 async/data3 async/data4
					SysFreeString bstr-m
					SysFreeString bstr-u
				]

				either hr >= 0 [
					if method = HTTP_POST [
						bstr-u: SysAllocString #u16 "Content-Type"
						bstr-m: SysAllocString #u16 "application/x-www-form-urlencoded"
						http/SetRequestHeader IH/ptr bstr-u bstr-m
						SysFreeString bstr-m
						SysFreeString bstr-u
					]
					if all [method = HTTP_POST header <> null][
						s: GET_BUFFER(header)
						value: s/offset + header/head
						tail:  s/tail

						while [value < tail][
							bstr-u: SysAllocString unicode/to-utf16 word/to-string as red-word! value
							value: value + 1
							bstr-m: SysAllocString unicode/to-utf16 as red-string! value
							value: value + 1
							http/SetRequestHeader IH/ptr bstr-u bstr-m
							SysFreeString bstr-m
							SysFreeString bstr-u
						]
					]
					hr: http/Send IH/ptr body/data1 body/data2 body/data3 body/data4
				][
					fire [TO_ERROR(access no-connect) url]
				]

				if hr >= 0 [
					if method = HTTP_POST [SysFreeString bstr-d]
					hr: http/ResponseBody IH/ptr body
				]

				if hr >= 0 [				
					array: body/data3
					if all [
						VT_ARRAY or VT_UI1 = body/data1
						1 = SafeArrayGetDim array
					][
						l-bound: 0
						u-bound: 0
						SafeArrayGetLBound array 1 :l-bound
						SafeArrayGetUBound array 1 :u-bound
						buf-ptr: 0
						SafeArrayAccessData array :buf-ptr
						len: u-bound - l-bound + 1
						res: as red-value! either binary? [
							binary/load as byte-ptr! buf-ptr len
						][
							string/load as c-string! buf-ptr len UTF-8
						]
						SafeArrayUnaccessData array
					]
					if body/data1 and VT_ARRAY > 0 [SafeArrayDestroy array]
				]

				if http <> null [http/Release IH/ptr]
				res
			]
		]
		MacOSX [
			#import [
				"/System/Library/Frameworks/CFNetwork.framework/CFNetwork" cdecl [
					__CFStringMakeConstantString: "__CFStringMakeConstantString" [
						cStr		[c-string!]
						return:		[integer!]
					]
					CFURLCreateWithString: "CFURLCreateWithString" [
						allocator	[integer!]
						url			[integer!]
						baseUrl		[integer!]
						return:		[integer!]
					]
					CFHTTPMessageCreateRequest: "CFHTTPMessageCreateRequest" [
						allocator	[integer!]
						method		[integer!]
						url			[integer!]
						version		[integer!]
						return:		[integer!]
					]
					CFHTTPMessageSetBody: "CFHTTPMessageSetBody" [
						msg			[integer!]
						data		[integer!]
					]
					CFHTTPMessageSetHeaderFieldValue: "CFHTTPMessageSetHeaderFieldValue" [
						msg			[integer!]
						header		[integer!]
						value		[integer!]
					]
					CFReadStreamCreateForHTTPRequest: "CFReadStreamCreateForHTTPRequest" [
						allocator	[integer!]
						request		[integer!]
						return:		[integer!]
					]
				]
				"/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation" cdecl [
					CFReadStreamOpen: "CFReadStreamOpen" [
						stream		[integer!]
						return:		[integer!]
					]
					CFReadStreamRead: "CFReadStreamRead" [
						stream		[integer!]
						buffer		[byte-ptr!]
						size		[integer!]
						return:		[integer!]
					]
					CFReadStreamClose: "CFReadStreamClose" [
						stream		[integer!]
					]
					CFDataCreate: "CFDataCreate" [
						allocator	[integer!]
						data		[byte-ptr!]
						length		[integer!]
						return:		[integer!]
					]
					CFStringCreateWithCString: "CFStringCreateWithCString" [
						allocator	[integer!]
						cStr		[c-string!]
						encoding	[integer!]
						return:		[integer!]
					]
					CFURLCreateStringByAddingPercentEscapes: "CFURLCreateStringByAddingPercentEscapes" [
						allocator	[integer!]
						cf-str		[integer!]
						unescaped	[integer!]
						escaped		[integer!]
						encoding	[integer!]
						return:		[integer!]
					]
					CFReadStreamSetProperty: "CFReadStreamSetProperty" [
						stream		[integer!]
						name		[integer!]
						value		[integer!]
						return:		[integer!]
					]
					CFRelease: "CFRelease" [
						cf			[integer!]
					]
				]
			]

			#define kCFStringEncodingUTF8	08000100h
			
			#define CFSTR(cStr)		[__CFStringMakeConstantString cStr]
			#define CFString(cStr)	[CFStringCreateWithCString 0 cStr kCFStringEncodingUTF8]

			request-http: func [
				method	[integer!]
				url		[red-url!]
				header	[red-block!]
				data	[red-value!]
				binary? [logic!]
				return: [red-value!]
				/local
					len			[integer!]
					action		[c-string!]
					raw-url		[integer!]
					escaped-url [integer!]
					cf-url		[integer!]
					req			[integer!]
					body		[integer!]
					buf			[byte-ptr!]
					datalen		[integer!]
					cf-key		[integer!]
					cf-val		[integer!]
					value		[red-value!]
					tail		[red-value!]
					s			[series!]
					bin			[red-binary!]
					stream		[integer!]
			][
				switch method [
					HTTP_GET  [action: "GET"]
					HTTP_PUT  [action: "PUT"]
					HTTP_POST [action: "POST"]
					default [--NOT_IMPLEMENTED--]
				]

				body: 0
				len: -1
				raw-url: CFString((unicode/to-utf8 as red-string! url :len))
				escaped-url: CFURLCreateStringByAddingPercentEscapes 0 raw-url 0 0 kCFStringEncodingUTF8
				cf-url: CFURLCreateWithString 0 escaped-url 0

				req: CFHTTPMessageCreateRequest 0 CFSTR(action) cf-url CFSTR("HTTP/1.1")
				CFRelease raw-url
				CFRelease escaped-url

				if zero? req [fire [TO_ERROR(access no-connect) url]]

				if any [method = HTTP_POST method = HTTP_PUT][
					datalen: -1
					either TYPE_OF(data) = TYPE_STRING [
						buf: as byte-ptr! unicode/to-utf8 as red-string! data :datalen
					][
						buf: binary/rs-head as red-binary! data
						datalen: binary/rs-length? as red-binary! data
					]
					body: CFDataCreate 0 buf datalen
					CFHTTPMessageSetBody req body

					CFHTTPMessageSetHeaderFieldValue req CFSTR("Content-Type") CFSTR("application/x-www-form-urlencoded; charset=utf-8")

					if header <> null [
						s: GET_BUFFER(header)
						value: s/offset + header/head
						tail:  s/tail

						while [value < tail][
							len: -1
							cf-key: CFSTR((unicode/to-utf8 word/to-string as red-word! value :len))
							value: value + 1
							len: -1
							cf-val: CFString((unicode/to-utf8 as red-string! value :len))
							value: value + 1
							CFHTTPMessageSetHeaderFieldValue req cf-key cf-val
							CFRelease cf-val
						]
					]
				]

				stream: CFReadStreamCreateForHTTPRequest 0 req
				if zero? stream [fire [TO_ERROR(access no-connect) url]]

				CFReadStreamSetProperty stream CFSTR("kCFStreamPropertyHTTPShouldAutoredirect") platform/true-value
				CFReadStreamOpen stream
				buf: allocate 4096
				bin: binary/make-at stack/push* 4096
				until [
					len: CFReadStreamRead stream buf 4096
					if len > 0 [
						binary/rs-append bin buf len
					]
					len <= 0
				]

				free buf
				CFReadStreamClose stream
				unless zero? body [CFRelease body]
				CFRelease cf-url
				CFRelease req
				CFRelease stream

				unless binary? [
					buf: binary/rs-head bin
					len: binary/rs-length? bin
					bin/header: TYPE_STRING
					bin/node: unicode/load-utf8 as c-string! buf len
				]
				as red-value! bin
			]
		]
		#default [
	
			#define CURLOPT_URL				10002
			#define CURLOPT_HTTPGET			80
			#define CURLOPT_POSTFIELDSIZE	60
			#define CURLOPT_NOPROGRESS		43
			#define CURLOPT_FOLLOWLOCATION	52
			#define CURLOPT_POSTFIELDS		10015
			#define CURLOPT_WRITEDATA		10001
			#define CURLOPT_HTTPHEADER		10023
			#define CURLOPT_WRITEFUNCTION	20011

			#define CURLE_OK				0
			#define CURL_GLOBAL_ALL 		3

			;-- use libcurl, may need to install it on some distros
			#import [
				"libcurl.so.4" cdecl [
					curl_global_init: "curl_global_init" [
						flags	[integer!]
						return: [integer!]
					]
					curl_easy_init: "curl_easy_init" [
						return: [integer!]
					]
					curl_easy_setopt: "curl_easy_setopt" [
						curl	[integer!]
						option	[integer!]
						param	[integer!]
						return: [integer!]
					]
					curl_slist_append: "curl_slist_append" [
						slist	[integer!]
						pragma	[c-string!]
						return:	[integer!]
					]
					curl_slist_free_all: "curl_slist_free_all" [
						slist	[integer!]
					]
					curl_easy_perform: "curl_easy_perform" [
						handle	[integer!]
						return: [integer!]
					]
					curl_easy_strerror: "curl_easy_strerror" [
						error	[integer!]
						return: [c-string!]
					]
					curl_easy_cleanup: "curl_easy_cleanup" [
						handle	[integer!]
					]
					curl_global_cleanup: "curl_global_cleanup" []
				]
			]

			get-http-response: func [
				[cdecl]
				data	 [byte-ptr!]
				size	 [integer!]
				nmemb	 [integer!]
				userdata [byte-ptr!]
				return:	 [integer!]
				/local
					bin  [red-binary!]
					len  [integer!]
			][
				bin: as red-binary! userdata
				len: size * nmemb
				binary/rs-append bin data len
				len
			]

			request-http: func [
				method	[integer!]
				url		[red-url!]
				header	[red-block!]
				data	[red-value!]
				binary? [logic!]
				return: [red-value!]
				/local
					len		[integer!]
					curl	[integer!]
					res		[integer!]
					buf		[byte-ptr!]
					action	[c-string!]
					bin		[red-binary!]
					value	[red-value!]
					tail	[red-value!]
					s		[series!]
					str		[red-string!]
					slist	[integer!]
			][
				switch method [
					HTTP_GET  [action: "GET"]
					;HTTP_PUT  [action: "PUT"]
					HTTP_POST [action: "POST"]
					default [--NOT_IMPLEMENTED--]
				]

				curl_global_init CURL_GLOBAL_ALL
				curl: curl_easy_init

				if zero? curl [
					probe "ERROR: libcurl init failed."
					curl_global_cleanup
					return none-value
				]

				slist: 0
				len: -1
				bin: binary/make-at stack/push* 4096
				
				curl_easy_setopt curl CURLOPT_URL as-integer unicode/to-utf8 as red-string! url :len
				curl_easy_setopt curl CURLOPT_NOPROGRESS 1
				curl_easy_setopt curl CURLOPT_FOLLOWLOCATION 1
				
				curl_easy_setopt curl CURLOPT_WRITEFUNCTION as-integer :get-http-response
				curl_easy_setopt curl CURLOPT_WRITEDATA as-integer bin

				case [
					method = HTTP_GET [
						curl_easy_setopt curl CURLOPT_HTTPGET 1
					]
					method = HTTP_POST [
						if header <> null [
							s: GET_BUFFER(header)
							value: s/offset + header/head
							tail:  s/tail

							while [value < tail][
								str: word/to-string as red-word! value
								string/append-char GET_BUFFER(str) as-integer #":"
								string/append-char GET_BUFFER(str) as-integer #" "
								value: value + 1
								string/concatenate str as red-string! value -1 0 yes no
								len: -1
								slist: curl_slist_append slist unicode/to-utf8 str :len
								value: value + 1
							]
							curl_easy_setopt curl CURLOPT_HTTPHEADER slist
						]
						len: -1
						either TYPE_OF(data) = TYPE_STRING [
							buf: as byte-ptr! unicode/to-utf8 as red-string! data :len
						][
							buf: binary/rs-head as red-binary! data
							len: binary/rs-length? as red-binary! data
						]
						curl_easy_setopt curl CURLOPT_POSTFIELDSIZE len
						curl_easy_setopt curl CURLOPT_POSTFIELDS as-integer buf
					]
				]
				res: curl_easy_perform curl

				unless zero? slist [curl_slist_free_all slist]
				curl_easy_cleanup curl
				curl_global_cleanup

				if res <> CURLE_OK [
					print-line ["ERROR: " curl_easy_strerror res]
					return none-value
				]

				unless binary? [
					buf: binary/rs-head bin
					len: binary/rs-length? bin
					bin/header: TYPE_STRING
					bin/node: unicode/load-utf8 as c-string! buf len
				]
				as red-value! bin
			]
		]
	]
]
