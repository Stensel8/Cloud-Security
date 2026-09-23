import {useContext, useRef, useState} from "react";
import {createProduct} from "../services/ApiService";
import {useNavigate} from'react-router-dom';
import {ProductContext} from "../context/ProductContext";
import {blockNonNumericKeys} from "../utils/numericInput";

export default function CreateProductForm() {

  const navigate = useNavigate();
  const titleRef = useRef();
  const priceRef = useRef();
  const quantityRef = useRef();
  const [error, setError] = useState(null);

  const {addProduct} = useContext(ProductContext);

  async function add(event) {
    event.preventDefault();
    setError(null);

    try {

      const newProduct = {
        title: titleRef.current.value,
        price: priceRef.current.value,
        quantity: quantityRef.current.value
      };

      const response = await createProduct(newProduct);
      addProduct(response);
      navigate(`/${response.id}`);

    } catch (error) {
      setError(error.response?.data?.message || error.response?.data?.error || 'Could not save the product. Check your input and try again.');
    }
  }

  return(
    <form onSubmit={add}>
      {error && <div className="alert alert-danger" role="alert">{error}</div>}
      <div className="mb-3 mt-5">
        <label htmlFor="title" className="form-label">Title</label>
        <input ref={titleRef} type="text" className="form-control" id="title" aria-describedby="titleHelp" />
        <div id="titleHelp" className="form-text">Input the product title here.</div>
      </div>
      <div className="mb-3">

        <div className="row">
          <div className="col-6">
            <label htmlFor="price" className="form-label">Price</label>
            <div className="input-group">
              <span className="input-group-text">€</span>
              <input ref={priceRef} type="number" min="0" step="0.01" onKeyDown={blockNonNumericKeys} className="form-control" id="price" />
            </div>
          </div>
          <div className="col-6">
            <label htmlFor="quantity" className="form-label">Quantity</label>
            <input ref={quantityRef} type="number" min="0" step="1" onKeyDown={blockNonNumericKeys} className="form-control" id="quantity" />
          </div>
        </div>

      </div>
      <button type="submit" className="btn btn-primary">Add</button>
    </form>
  );

}