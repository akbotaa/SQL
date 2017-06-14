import xml.sax
from xml.sax import handler
import os, re
import pandas as pd
import psycopg2
import sys

try:
    con = psycopg2.connect(dbname='dblp', user='dblpuser', host='localhost', password='password')
except:
    print ("I am unable to connect to the database")
    
cur = con.cursor()
con.autocommit=True #commit changes automatically

#Drop tables if they already exist, and create new ones
cur.execute("DROP TABLE IF EXISTS Article")
cur.execute("DROP TABLE IF EXISTS Inproceedings")
cur.execute("DROP TABLE IF EXISTS Authorship")

cur.execute("CREATE TABLE Article(pubkey VARCHAR(70), title VARCHAR(700), journal VARCHAR(200), year INT, PRIMARY KEY(pubkey))")
cur.execute("CREATE TABLE Inproceedings(pubkey VARCHAR(70), title VARCHAR(700), booktitle VARCHAR(200), year INT, PRIMARY KEY(pubkey))")
cur.execute("CREATE TABLE Authorship(pubkey VARCHAR(70), author VARCHAR(100), PRIMARY KEY(pubkey, author))")


os.chdir("/Users/akbota/Documents/fall, 16/Big Data/hw 1")

class HwHandler( xml.sax.ContentHandler ):
    def __init__(self):
        self.CurrentData = ""
        self.bool = False
        self.author = ""
        self.title = ""
        self.jb = ""       #either journal or booktitle
        self.year = ""
        self.pubkey = ""
        self.count = 0

# Call when an element starts
    def startElement(self, tag, attributes):
        self.CurrentData = tag

        if tag == "article" or tag == "inproceedings":
            self.bool = True
            self.pubkey = attributes["key"]

        elif tag=="author":
            self.author = ""
            
# Call when a character is read
    def characters(self, content):
        if self.bool == True:
            if self.CurrentData == "title":
                self.title += content
            
            elif self.CurrentData == "author":
                self.author += content

            elif self.CurrentData == "journal" or self.CurrentData == "booktitle":
                self.jb += content
            
            elif self.CurrentData == "year":
                self.year += content
                        
# Call when an elements ends
    def endElement(self, tag):
        if self.bool == True:
            self.CurrentData=""
            if tag == "author":
                try:
                    cur.execute("INSERT INTO Authorship (pubkey, author) VALUES (%s, %s);", (self.pubkey, self.author))
                except psycopg2.IntegrityError:
                    print("Authorship duplicate found!")
                
            elif tag == "article":
                self.count += 1
                if self.count % 5000==0:
                    print(self.count)
                    
                #deal with empty entries
                if self.jb=="":
                    self.jb=None
                if self.title=="":
                    self.title=None
                if self.year=="":
                    self.year=None
                      
                cur.execute("INSERT INTO Article (pubkey, title, journal, year) VALUES (%s, %s, %s, %s);", (self.pubkey, self.title, self.jb, self.year))
                    
                self.CurrentData = ""
                self.bool = False
                self.title = ""
                self.jb = ""       #either journal or booktitle
                self.year = ""
                
            elif tag == "inproceedings":
                self.count += 1
                    
                #deal with empty entries
                if self.jb=="":
                    self.jb=None
                if self.title=="":
                    self.title=None
                if self.year=="":
                    self.year=None
                
                cur.execute("INSERT INTO Inproceedings (pubkey, title, booktitle, year) VALUES (%s, %s, %s, %s);", (self.pubkey, self.title, self.jb, self.year))
                self.CurrentData = ""
                self.bool = False
                self.title = ""
                self.jb = ""       #either journal or booktitle
                self.year = ""
                

parser = xml.sax.make_parser()

Handler = HwHandler()

parser.setContentHandler(Handler)
parser.parse(open('dblp-2015-12-01.xml'))

#close the database

con.close()