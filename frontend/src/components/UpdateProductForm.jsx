import {useContext, useEffect, useState} from "react";
import {getProductById, updateProductById} from "../services/ApiService";
import {NavLink, useNavigate, useParams} from 'react-router-dom';
import {ProductContext} from "../context/ProductContext";
import {blockNonNumericKeys} from "../utils/numericInput";
import NotFound from "./NotFound";

export default function UpdateProductForm() {

  const { id } = useParams();
  const navigate = useNavigate();
  const {product, updateProduct} = useContext(ProductContext);
  const [error, setError] = useState(null);
  const [notFound, setNotFound] = useState(false);

  async function update(event) {
    event.preventDefault();
    setError(null);

    try {
      const response = await updateProductById(id, product);
      navigate(`/${response.id}`);
    } catch (error) {
      setError(error.response?.data?.message || error.response?.data?.error || 'Could not save the product. Check your input and try again.');
    }
  }

  useEffect(() => {
    let cancelled = false;

    async function fetchData() {
      try {
        const product = await getProductById(id);
        if (!cancelled) {
          updateProduct(product);
          setNotFound(false);
        }
      } catch {
        if (!cancelled) {
          setNotFound(true);
        }
      }
    }

    fetchData();
    return () => { cancelled = true; };
  }, [id]);

  if (notFound) {
    return <NotFound />;
  }

  const handleChange = (event) => {
    const { id, value } = event.target;

    switch (id) {
      case "title":
        updateProduct({...product, title: value});
        break;
      case "price":
        updateProduct({...product, price: value});
        break;
      case "quantity":
        updateProduct({...product, quantity: value});
        break;
      default:
        break;
    }
  };

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
          <li className="breadcrumb-item active">
            <NavLink to={`/${id}/edit`}>edit</NavLink>
          </li>
        </ol>
      </nav>
      <form onSubmit={update}>
        {error && <div className="alert alert-danger" role="alert">{error}</div>}
        <div className="mb-3 mt-5">
          <label htmlFor="title" className="form-label">Title</label>
          <input onChange={handleChange} value={product.title} type="text" className="form-control" id="title" aria-describedby="titleHelp" />
          <div id="titleHelp" className="form-text">Input the product title here.</div>
        </div>
        <div className="mb-3">

          <div className="row">
            <div className="col-6">
              <label htmlFor="price" className="form-label">Price</label>
              <div className="input-group">
                <span className="input-group-text">€</span>
                <input onChange={handleChange} onKeyDown={blockNonNumericKeys} value={product.price} type="number" min="0" step="0.01" className="form-control" id="price" />
              </div>
            </div>
            <div className="col-6">
              <label htmlFor="quantity" className="form-label">Quantity</label>
              <input onChange={handleChange} onKeyDown={blockNonNumericKeys} value={product.quantity} type="number" min="0" step="1" className="form-control" id="quantity" />
            </div>
          </div>

        </div>
        <button type="submit" className="btn btn-primary">Update</button>
      </form>
    </div>
  );

}