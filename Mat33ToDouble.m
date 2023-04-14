function mat3x3 = Mat33ToDouble(mat33)
import org.opensim.modeling.*
mat3x3 = nan(3,3);
for ii=1:3
    for jj=1:3
        mat3x3(ii,jj) = mat33.get(ii-1,jj-1);
    end
end %for
end %convert_Mat33