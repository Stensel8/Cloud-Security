import { NavLink } from "react-router-dom";
import {deleteProductById} from "../services/ApiService";
import {useContext, useState} from 'react';
import {ProductContext} from "../context/ProductContext";
import {formatCurrency} from "../utils/currency";

export default function ProductTableRow ({id, title, price, quantity}) {

  const {removeProductById} = useContext(ProductContext);
  const [deleteError, setDeleteError] = useState(null);

  async function deleteProduct() {
    setDeleteError(null);
    try {
      await deleteProductById(id);
      removeProductById(id);

    } catch (error) {
      setDeleteError(error.response?.data?.message || error.response?.data?.error || 'Could not delete the product. Try again.');
    }
  }

  return(
    <>
      <tr>
        <th scope="row">{id}</th>
        <td>{title}</td>
        <td>{formatCurrency(price)}</td>
        <td>{quantity}</td>
        <td>{formatCurrency(price * quantity)}</td>
        <td>
          <div className="btn-group">
            <NavLink className="btn btn-info" to={`/${id}`}>View</NavLink>
            <NavLink className="btn btn-light" to={`/${id}/edit`}>Edit</NavLink>
            <button onClick={deleteProduct} className="btn btn-danger">Delete</button>
          </div>
        </td>
      </tr>
      {deleteError && (
        <tr>
          <td colSpan="6">
            <div className="alert alert-danger mb-0" role="alert">{deleteError}</div>
          </td>
        </tr>
      )}
    </>
  );
}