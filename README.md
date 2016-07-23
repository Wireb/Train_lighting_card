### Induction refractory furnance supporting files

### licence 
Copyright (c) 2015 Peter Shabino

Permission is hereby granted, free of charge, to any person obtaining a copy of this hardware, software, and associated documentation files
(the "Product"), to deal in the Product without restriction, including without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Product, and to permit persons to whom the Product is furnished to do so, subject to the
following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Product.

THE PRODUCT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE PRODUCT OR THE USE OR OTHER DEALINGS IN THE PRODUCT.


### What is it
The current generation of controller card supports up to 11 normal LED channels plus one "special"  one that supports driving a bi-polar output. On the input side the controller will run off 6V to 60V AC or DC. (note I have NOT test this full range. I have tested 9Vac to 20Vac with no issues) It also has 4 opto-isolated inputs that will respond to ~3V to 32V AC or DC that can be used to pick one of 16 pre-programmed states. 

Currently there are 7 selectable states:
* Headlights
* running lights
* left turn
* right turn
* break lights
* reverse lights
* light bar flashers 

via the programing button any state, combination of states, or none can be chosen for each of the 16 combinations of inputs. 