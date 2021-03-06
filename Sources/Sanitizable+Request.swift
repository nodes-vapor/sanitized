import HTTP
import Node
import Vapor
import FluentProvider

extension Request {
    /// Extracts a `Model` from the Request's JSON, first stripping sensitive fields.
    ///
    /// - Throws:
    ///     - badRequest: Thrown when the request doesn't have a JSON body.
    ///     - updateErrorThrown: `Sanitizable` models have the ability to override
    ///         the error thrown when a model fails to instantiate.
    ///
    /// - Returns: The extracted, sanitized `Model`.
    public func extractModel<M: Model>() throws -> M where M: Sanitizable {
        return try extractModel(injecting: .null)
    }
    
    
    /// Extracts a `Model` from the Request's JSON, first by adding/overriding
    /// the given values and next stripping sensitive fields.
    ///
    /// - Parameter values: Values to set before sanitizing.
    /// - Returns: The extracted, sanitized `Model`.
    /// - Throws:
    ///     - badRequest: Thrown when the request doesn't have a JSON body.
    ///     - updateErrorThrown: `Sanitizable` models have the ability to override
    ///         the error thrown when a model fails to instantiate.
    public func extractModel<M: Model>(injecting values: Node) throws -> M where M: Sanitizable {
        guard let json = self.json else {
            throw Abort.badRequest
        }
        
        var sanitized = json.permit(M.permitted)
        values.object?.forEach { key, value in
            sanitized[key] = JSON(value)
        }
        
        try M.preValidate(data: sanitized)
        
        let model: M
        do {
            model = try M(json: sanitized)
        } catch {
            let error = M.updateThrownError(error)
            throw error
        }
        
        try model.postValidate()
        return model
    }
    
    /// Updates the `Model` with the provided `id`, first stripping sensitive fields
    ///
    /// - Parameters:
    ///     - id: id of the `Model` to fetch and then patch
    ///
    /// - Throws:
    ///     - notFound: No entity found with the provided `id`.
    ///     - badRequest: Thrown when the request doesn't have a JSON body.
    ///     - updateErrorThrown: `Sanitizable` models have the ability to override
    ///         the error thrown when a model fails to instantiate.
    ///
    /// - Returns: The updated `Model`.
    public func patchModel<M: Model>(id: NodeRepresentable) throws -> M where M: Sanitizable {
        guard let model = try M.find(id) else {
            throw Abort.notFound
        }
        
        return try patchModel(model)
    }
    
    /// Updates the provided `Model`, first stripping sensitive fields
    ///
    /// - Parameters:
    ///     - model: the `Model` to patch
    ///
    /// - Throws:
    ///     - badRequest: Thrown when the request doesn't have a JSON body.
    ///     - updateErrorThrown: `Sanitizable` models have the ability to override
    ///         the error thrown when a model fails to instantiate.
    ///
    /// - Returns: The updated `Model`.
    public func patchModel<M: Model>(_ model: M) throws -> M where M: Sanitizable {
        //consider making multiple lines
        guard let requestJSON = self.json?.permit(M.permitted).object else {
            throw Abort.badRequest
        }
        
        var modelJSON = try model.makeJSON()
        
        requestJSON.forEach {
            modelJSON[$0.key] = $0.value
        }
        
        var model: M
        do {
            model = try M(json: modelJSON)
        } catch {
            let error = M.updateThrownError(error)
            throw error
        }
        
        model.exists = true
        try model.postValidate()
        return model
    }
}
