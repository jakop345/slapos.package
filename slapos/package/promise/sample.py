

class Promise:
  
  def checkConsistency(self, fixit=0, **kw):
    print "checkConsistency invoked"
    if fixit:
      self.fixConsistency()

  def fixConsistency(self, **kw):
    print "Fixed Consistency"
  
