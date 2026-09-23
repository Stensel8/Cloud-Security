import {useContext, useEffect, useState} from 'react';
import ProductTableRow from "./ProductTableRow";
import { ProductContext } from "../context/ProductContext";
import { getProducts } from "../services/ApiService"
import {NavLink} from "react-router-dom";

export default function ProductList() {

  const { products, updateProducts } = useContext(ProductContext);
  const [loadError, setLoadError] = useState(null);

  useEffect(() => {
    async function fetchData() {
      try {
        const products = await getProducts();
        updateProducts(products);
        setLoadError(null);
      } catch (error) {
        setLoadError(error.response?.data?.message || error.response?.data?.error || 'Could not load the products. Try again.');
      }
    }

    fetchData();
  }, []);

  return(
    <div>
      <nav aria-label="breadcrumb">
        <ol className="breadcrumb">
          <li className="breadcrumb-item">
            <NavLink to="/">Products</NavLink>
          </li>
        </ol>
      </nav>
      {loadError && <div className="alert alert-danger" role="alert">{loadError}</div>}
      <table className="table table-striped">
        <thead>
        <tr>
          <th scope="col">#</th>
          <th scope="col">Title</th>
          <th scope="col">Price</th>
          <th scope="col">Quantity</th>
          <th scope="col">Total</th>
          <th scope="col">Actions</th>
        </tr>
        </thead>
        <tbody>
        {products.map(product => <ProductTableRow key={product.id} {...product} />)}
        </tbody>
      </table>
      <div>
        <NavLink className="btn btn-primary" to="/new">Add</NavLink>
      </div>
    </div>

  );

}