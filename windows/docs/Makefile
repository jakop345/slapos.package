#
#  Transfer Doc Book to html
#
#  Enter cygwin, be sure doc book installed. Then
#      
#    $ cd d:/slapos/src/docs
#    $ make
#
XSLTPROC=xsltproc
# Under Cygwin:
XSLFILE=/usr/share/sgml/docbook/xsl-stylesheets/html/docbook.xsl
XSLCHUNKFILE=/usr/share/sgml/docbook/xsl-stylesheets/html/chunk.xsl
# Under Linux/Ubuntu:
#XSLFILE=/usr/share/xml/docbook/stylesheet/docbook-xsl/html/docbook.xsl
#XSLCHUNKFILE=/usr/share/xml/docbook/stylesheet/docbook-xsl/html/chunk.xsl
XSLTPARA=--stringparam section.autolabel 1 \
         --stringparam section.label.includes.component.label 1 \
         --stringparam variablelist.term.separator "" \
         --stringparam variablelist.term.break.after 1

BASEDIR=--stringparam base.dir ./

doc: using-slapos-in-windows.html

%.html: %.xml
	$(XSLTPROC) $(XSLTPARA) --output $@ $(XSLFILE) $<
	#$(XSLTPROC) $(XSLTPARA) $(BASEDIR)/$(basename $<)/ $(XSLCHUNKFILE) $<

