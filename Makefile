CXX 		= 	g++
CXXFLAGS 	=	-Iinclude/
CXXFLAGS 	+= 	-no-pie
CXXFLAGS	+= 	-fopenmp -O3 -ffast-math
LDFLAGS 	= 	lib/libpng16.a lib/libz.a

OBJECTS 	= 	src/main.o src/image.o src/stencil.o

stencil: $(OBJECTS)
	$(CXX)  $(CXXFLAGS) -o bin/stencil $(OBJECTS) $(LDFLAGS)

all:	stencil

run:	all
	bin/stencil test-image.png

clean:
	rm -f $(OBJECTS) bin/stencil output.png src/*~ *~
