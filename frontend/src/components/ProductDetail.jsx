import {useEffect, useContext, useState} from "react";
import {NavLink, useParams, useNavigate} from "react-router-dom";
import {deleteProductById, getProductById} from "../services/ApiService";
import {ProductContext} from "../context/ProductContext";
import {formatCurrency} from "../utils/currency";
import NotFound from "./NotFound";

export default function ProductDetail() {

  const { id } = useParams();
  const { product, updateProduct, removeProductById } = useContext(ProductContext);
  const navigate = useNavigate();
  const [notFound, setNotFound] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);
  const [loadAttempt, setLoadAttempt] = useState(0);
  const [deleteError, setDeleteError] = useState(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchData() {
      setLoading(true);
      setLoadError(false);
      setNotFound(false);
      try {
        const product = await getProductById(id);
        if (!cancelled) {
          updateProduct(product);
          setNotFound(false);
        }
      } catch (error) {
        if (!cancelled) {
          if (error.response?.status === 404) {
            setNotFound(true);
          } else {
            setLoadError(true);
          }
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    fetchData();
    return () => { cancelled = true; };
  }, [id, loadAttempt, updateProduct]);

  if (loading) {
    return <p role="status">Loading product…</p>;
  }

  if (loadError) {
    return (
      <div className="alert alert-danger" role="alert">
        <p>Could not load the product. Please try again.</p>
        <button className="btn btn-primary" onClick={() => setLoadAttempt(attempt => attempt + 1)}>
          Try again
        </button>
      </div>
    );
  }

  if (notFound) {
    return <NotFound />;
  }

  async function deleteProduct() {
    setDeleteError(null);
    try {
      await deleteProductById(id);
      removeProductById(id);
      navigate("/");
    } catch (error) {
      setDeleteError(error.response?.data?.message || error.response?.data?.error || 'Could not delete the product. Try again.');
    }
  }

  return(
    <div>
      <nav aria-label="breadcrumb">
        <ol className="breadcrumb">
          <li className="breadcrumb-item">
            <NavLink to="/">Products</NavLink>
          </li>
          <li className="breadcrumb-item">
            <NavLink to={`/${id}`}>{id}</NavLink>
          </li>
        </ol>
      </nav>
      <h4 className="text-center mb-5 mt-5">Product Info: {id}</h4>
      {deleteError && <div className="alert alert-danger" role="alert">{deleteError}</div>}
      <table className="table">
        <tbody>
        <tr>
          <th scope="row">Title</th>
          <td>{product.title}</td>
        </tr>
        <tr>
          <th scope="row">Price</th>
          <td>{formatCurrency(product.price)}</td>
        </tr>
        <tr>
          <th scope="row">Quantity</th>
          <td>{product.quantity}</td>
        </tr>
        <tr>
          <th scope="row">Total</th>
          <td>{formatCurrency(product.price * product.quantity)}</td>
        </tr>
        </tbody>
      </table>
      <div>
        <div className="row">
          <div className="col-6">
            <NavLink className="btn btn-light" to={`/${id}/edit`}>Edit</NavLink>
          </div>
          <div className="col-6 text-end">
            <button onClick={deleteProduct} className="btn btn-danger pull-right">Delete</button>
          </div>
        </div>
      </div>
    </div>
  );

}