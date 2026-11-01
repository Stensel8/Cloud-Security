import { useCallback, useState } from 'react';
import { ProductContext } from './ProductContext';

export const ProductListProvider = ({ children }) => {
  const [products, setProducts] = useState([]);
  const [product, setProduct] = useState({});

  const updateProducts = useCallback((products) => {
    setProducts(products);
  }, []);

  const addProduct = useCallback((product) => {
    setProducts((prev) => [...prev, product]);
  }, []);

  const updateProduct = useCallback((product) => {
    setProduct(product);
  }, []);

  const removeProductById = useCallback((id) => {
    setProducts((prev) => prev.filter((product) => product.id !== id));
  }, []);

  return (
    <ProductContext.Provider value={{ products, product, updateProducts, updateProduct, removeProductById, addProduct }}>
      {children}
    </ProductContext.Provider>
  );
};
