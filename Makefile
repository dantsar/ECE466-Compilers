CFLAGS= -std=gnu11 -ggdb -Wpedantic -fsanitize=undefined
CC=clang

all: parser

char_util.o: char_util.c char_util.h
	$(CC) $(CFLAGS) -c -o char_util.o char_util.c

parser.tab.h: parser.y def.h
	bison -vd parser.y

parser.tab.o: parser.tab.h
	$(CC) $(CFLAGS) -c -o parser.tab.o parser.tab.c

lex.yy.c: lex.l parser.tab.o
	flex lex.l

lex.yy.o: lex.yy.c 
	$(CC) $(CFLAGS) -c -o lex.yy.o lex.yy.c

# need to fix this...but later!
lex: lex_print.c lex.yy.o char_util.o   ast.o sym_tab.o
	$(CC) $(CFLAGS) -DLEXER -c -o parser.tab.o parser.tab.c
	$(CC) $(CFLAGS) -o lex  $^ parser.tab.o

ast.o: ast.h ast.c sym_tab.h
	$(CC) $(CFLAGS) -c -o ast.o ast.c

sym_tab.o: sym_tab.c sym_tab.h
	$(CC) $(CFLAGS) -c -o sym_tab.o sym_tab.c

parser_print.o: parser_print.c parser_print.h
	$(CC) $(CFLAGS) -c -o parser_print.o parser_print.c

parser: parser.tab.o lex.yy.o ast.o sym_tab.o char_util.o parser_print.o
	$(CC) $(CFLAGS) -o parser $^

clean: 
	rm *.o lex.yy.c parser.tab.h parser.tab.c parser parser.output 