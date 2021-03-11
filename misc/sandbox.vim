let s:Markdown = vital#vital#import('VS.Vim.Syntax.Markdown')

syntax reset
call s:Markdown.apply()

finish

```php array_map($callback, array $arr1, array ...$_) ``` 

__array\_map__ 

Applies the callback to the elements of the given arrays
```php <?php
function array_map($callback, array $arr1, array ...$_
) { } ```

_@param_ `callback $callback`   Callback function to run for each element in each array. 
_@param_ `array $arr1` — An array to run through the callback function. 
_@param_ `array ...$_` — \[optional\] 
_@return_ `array` an array containing all the elements of arr1 after applying the callback function to each one.
_@link_ https://php.net/manual/en/function.array-map.php
_@meta_
